///|
priv enum Command {
  List
  Get(String)
  Search(String)
  Recommend(String)
}

///|
priv struct ParsedArgs {
  command : Command
  as_json : Bool
}

///|
fn parse_args(args : Array[String]) -> Result[ParsedArgs, String] {
  let usage = "usage: skillbox [--format=json] list | get <name> | search <query> | recommend <query>"
  let positional : Array[String] = []
  let mut as_json = false
  let mut literal = false
  for arg in args[1:] {
    match (literal, arg) {
      (false, "--") => literal = true
      (false, "--format=json") => as_json = true
      (false, "--json") => return Err("use --format=json instead of --json")
      (false, option) if option.has_prefix("--format=") =>
        return Err("unsupported format: " + option)
      _ => positional.push(arg)
    }
  }
  let command = match positional {
    ["list"] => List
    ["get", name] => Get(name)
    ["search", query] => Search(query)
    ["recommend", query] => Recommend(query)
    _ => return Err(usage)
  }
  Ok({ command, as_json, })
}
