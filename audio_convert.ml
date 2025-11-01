open Unix

let usage_msg = "audio-convert -i <PATH> [options]"

let input = ref ""
let output_opt = ref None
let quality = ref "high"
let mp3_bitrate = ref None
let ogg_quality = ref None
let trim_silence = ref false
let silence_threshold = ref (-50)
let silence_min_ms = ref 200
let force = ref false
let dry_run = ref false
let verbose = ref false
let help = ref false

let specs = [
  ("-i", Arg.Set_string input, " <PATH> Input file or directory");
  ("--input", Arg.Set_string input, " <PATH> Same as -i");
  ("-o", Arg.String (fun s -> output_opt := Some s), " <PATH> Output directory");
  ("--output", Arg.String (fun s -> output_opt := Some s), " <PATH> Same as -o");
  ("--quality", Arg.Set_string quality, " {low|medium|high|insane} Quality preset (default: high)");
  ("--mp3-bitrate", Arg.Int (fun i -> mp3_bitrate := Some i), " <kbps> Override MP3 bitrate");
  ("--ogg-quality", Arg.Int (fun i -> ogg_quality := Some i), " <q> Override OGG quality (-1..10)");
  ("--trim-silence", Arg.Set trim_silence, " Enable silence trimming");
  ("--silence-threshold", Arg.Set_int silence_threshold, " <dB> Silence threshold (default: -50)");
  ("--silence-min-ms", Arg.Set_int silence_min_ms, " <ms> Min silence duration (default: 200)");
  ("--force", Arg.Set force, " Overwrite existing outputs");
  ("--dry-run", Arg.Set dry_run, " Print planned work, do not write");
  ("-v", Arg.Set verbose, " Verbose output");
  ("--verbose", Arg.Set verbose, " Same as -v");
  ("-h", Arg.Set help, " Show help");
  ("--help", Arg.Set help, " Same as -h");
]

let () =
  Arg.parse specs (fun _ -> ()) usage_msg;
  if !help || !input = "" then begin
    Arg.usage specs usage_msg;
    exit (if !input = "" then 1 else 0)
  end;
  if not (List.mem !quality ["low"; "medium"; "high"; "insane"]) then begin
    Printf.eprintf "Invalid quality: %s\n" !quality;
    exit 1
  end

let is_supported_ext path =
  let ext = String.lowercase_ascii (Filename.extension path) in
  List.mem ext [".wav"; ".aif"; ".aiff"; ".flac"; ".m4a"]

let rec mkdir_p path =
  if Sys.file_exists path then ()
  else begin
    mkdir_p (Filename.dirname path);
    Unix.mkdir path 0o755
  end

let run_cmd prog args dry verbose =
  let cmd_str = String.concat " " (prog :: (Array.to_list args)) in
  if dry || verbose then Printf.printf "%s: %s\n" (if dry then "Would run" else "Running") cmd_str;
  if dry then 0
  else begin
    let null_fd = if verbose then stderr else openfile "/dev/null" [O_WRONLY] 0 in
    let pid = create_process prog (Array.of_list (prog :: Array.to_list args)) stdin stdout null_fd in
    if not verbose then close null_fd;
    let _, status = waitpid [] pid in
    match status with
    | WEXITED code -> code
    | _ -> 1
  end

let collect_files input =
  let rec aux dir acc =
    let files = Sys.readdir dir in
    Array.fold_left (fun acc f ->
      let path = Filename.concat dir f in
      if Sys.is_directory path then aux path acc
      else if is_supported_ext path then path :: acc else acc
    ) acc files
  in
  if Sys.is_directory input then List.rev (aux input [])
  else if is_supported_ext input then [input] else failwith ("Unsupported input: " ^ input)

let process_file input_file output_opt input_base quality mp3_bitrate ogg_quality trim_silence silence_threshold silence_min_ms force dry_run verbose =
  let basename = Filename.chop_extension (Filename.basename input_file) in
  let rel_path =
    let base_len = String.length input_base in
    if String.sub input_file 0 base_len = input_base then
      String.sub input_file (base_len + 1) (String.length input_file - base_len - 1)
    else failwith "Path mismatch"
  in
  let out_dir = match output_opt with
    | None -> Filename.dirname input_file
    | Some o ->
        let rel_dir = Filename.dirname rel_path in
        let d = Filename.concat o rel_dir in
        mkdir_p d;
        d
  in
  let af =
    if trim_silence then
      let thresh = Printf.sprintf "%ddB" silence_threshold in
      let sil = Printf.sprintf "%.3f" (float silence_min_ms /. 1000.) in
      ["-af"; "silenceremove=start_periods=1:start_threshold=" ^ thresh ^ ":start_silence=" ^ sil ^
              ":stop_periods=1:stop_threshold=" ^ thresh ^ ":stop_silence=" ^ sil]
    else []
  in
  let common = ["-y"; "-hide_banner"; "-loglevel"; "error"; "-i"; input_file] @ af in
  let convert ext encoder_args =
    let out_final = Filename.concat out_dir (basename ^ "." ^ ext) in
    if Sys.file_exists out_final && not force then begin
      if dry_run || verbose then Printf.printf "Skipping %s (exists)\n" out_final;
      0
    end else begin
      let temp = Filename.temp_file ~temp_dir:out_dir "conv_" ("." ^ ext) in
      let args = common @ encoder_args @ [temp] in
      let code = run_cmd "ffmpeg" (Array.of_list args) dry_run verbose in
      if code = 0 && not dry_run then rename temp out_final;
      if code <> 0 then 1 else 0
    end
  in
  let mp3_q = match quality with "low" -> 6 | "medium" -> 4 | "high" -> 2 | "insane" -> -1 | _ -> assert false in
  let mp3_encoder =
    match mp3_bitrate with
    | Some br -> ["-c:a"; "libmp3lame"; "-b:a"; Printf.sprintf "%dk" br]
    | None ->
        if mp3_q = -1 then ["-c:a"; "libmp3lame"; "-b:a"; "320k"]
        else ["-c:a"; "libmp3lame"; "-qscale:a"; string_of_int mp3_q]
  in
  let ogg_q = match ogg_quality with
    | Some q -> q
    | None -> match quality with "low" -> 2 | "medium" -> 4 | "high" -> 6 | "insane" -> 8 | _ -> assert false
  in
  let ogg_encoder = ["-c:a"; "libvorbis"; "-qscale:a"; string_of_int ogg_q] in
  let code_mp3 = convert "mp3" mp3_encoder in
  let code_ogg = convert "ogg" ogg_encoder in
  if code_mp3 <> 0 || code_ogg <> 0 then 1 else 0

let () =
  let input_base = if Sys.is_directory !input then !input else Filename.dirname !input in
  let files = collect_files !input in
  let exit_code = ref 0 in
  List.iter (fun f ->
    let code = process_file f !output_opt input_base !quality !mp3_bitrate !ogg_quality !trim_silence !silence_threshold !silence_min_ms !force !dry_run !verbose in
    if code <> 0 then exit_code := 1
  ) files;
  exit !exit_code