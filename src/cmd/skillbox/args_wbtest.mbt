///|
test "CLI parses flags and literal query words without side effects" {
  let list = parse_args(["skillbox", "--format=json", "list"]).unwrap()
  inspect(list.as_json, content="true")
  inspect(list.command is List, content="true")
  let query = parse_args([
    "skillbox", "search", "browser testing", "--format=json",
  ]).unwrap()
  inspect(query.as_json, content="true")
  match query.command {
    Search(text) => inspect(text, content="browser testing")
    _ => fail("expected search")
  }
  let literal = parse_args(["skillbox", "search", "--", "--format=json"]).unwrap()
  inspect(literal.as_json, content="false")
  match literal.command {
    Search(text) => inspect(text, content="--format=json")
    _ => fail("expected search")
  }
  let mixed = parse_args([
    "skillbox", "--format=json", "recommend", "--", "--format=json this task",
  ]).unwrap()
  inspect(mixed.as_json, content="true")
  match mixed.command {
    Recommend(text) => inspect(text, content="--format=json this task")
    _ => fail("expected recommend")
  }
  let get = parse_args(["skillbox", "get", "agent-browser", "--format=json"]).unwrap()
  inspect(get.as_json, content="true")
  match get.command {
    Get(name) => inspect(name, content="agent-browser")
    _ => fail("expected get")
  }
  let literal_name = parse_args(["skillbox", "get", "--", "--format=json"]).unwrap()
  inspect(literal_name.as_json, content="false")
  match literal_name.command {
    Get(name) => inspect(name, content="--format=json")
    _ => fail("expected get")
  }
  inspect(parse_args(["skillbox", "get"]) is Err(_), content="true")
  inspect(
    parse_args(["skillbox", "list", "--format=xml"]) is Err(_),
    content="true",
  )
  inspect(
    parse_args(["skillbox", "search", "foo", "--format=xml"]) is Err(_),
    content="true",
  )
  inspect(
    parse_args(["skillbox", "search", "foo", "--json"]) is Err(_),
    content="true",
  )
  inspect(
    parse_args(["skillbox", "get", "one", "two"]) is Err(_),
    content="true",
  )
  inspect(parse_args(["skillbox", "search", "--"]) is Err(_), content="true")
  inspect(
    parse_args(["skillbox", "search", "browser", "testing"]) is Err(_),
    content="true",
  )
  inspect(
    parse_args(["skillbox", "recommend", "test", "forms"]) is Err(_),
    content="true",
  )
  inspect(parse_args(["skillbox", "recommend"]) is Err(_), content="true")
  inspect(parse_args(["skillbox", "list", "extra"]) is Err(_), content="true")
}
