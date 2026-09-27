///|
async test "mounted filesystem skill discovery is host-independent" {
  let fs = @core.FsHost::{
    exists: path => path == "/home" || path == "/project",
    read_dir: path => {
      match path {
        "/home" => ["SKILL.md"]
        "/project" => ["SKILL.md", "broken", "loop"]
        "/project/broken" => ["SKILL.md"]
        _ => []
      }
    },
    kind: path => {
      if path == "/project/broken" || path == "/project/loop" {
        Directory
      } else if path.has_suffix("/SKILL.md") {
        Regular
      } else {
        Other
      }
    },
    realpath: path => if path == "/project/loop" { "/project" } else { path },
    read_file: path => {
      match path {
        "/home/SKILL.md" => "---\nname: shared\ndescription: home\n---\n"
        "/project/SKILL.md" => "---\nname: shared\ndescription: project\n---\n"
        _ => "missing front matter"
      }
    },
    join: (base, name) => base + "/" + name,
  }
  let catalog = @core.load_skills(fs, ["/project", "/home"])
  let skills = catalog.skills.unwrap()
  inspect(skills.length(), content="1")
  inspect(skills[0].description, content="project")
  inspect(catalog.diagnostics.length(), content="1")
  inspect(
    catalog.diagnostics[0].contains("/project/broken/SKILL.md"),
    content="true",
  )
}

///|
async test "catalog errors preserve file diagnostics" {
  let fs = @core.FsHost::{
    exists: path => path == "/skills",
    read_dir: _ => ["a", "b", "broken"],
    kind: _ => Regular,
    realpath: path => path,
    read_file: path => {
      if path.has_suffix("/broken") {
        "invalid"
      } else {
        "---\nname: same\ndescription: test\n---\n"
      }
    },
    join: (root, name) => root + "/" + name,
  }
  // SKILL.md selection is performed by core, not by the host.
  let ignored = @core.load_skills(fs, ["/skills"])
  inspect(ignored.skills.unwrap().length(), content="0")
  let fs = @core.FsHost::{
    exists: path => path == "/skills",
    read_dir: path => {
      if path == "/skills" {
        ["a", "b", "broken"]
      } else {
        ["SKILL.md"]
      }
    },
    kind: path => if path.has_suffix("SKILL.md") { Regular } else { Directory },
    realpath: path => path,
    read_file: path => {
      if path.contains("broken") {
        "invalid"
      } else {
        "---\nname: same\ndescription: test\n---\n"
      }
    },
    join: (root, name) => root + "/" + name,
  }
  let result = @core.load_skills(fs, ["/skills"])
  match result.skills {
    Err(message) => {
      inspect(message.contains("/skills/a/SKILL.md"), content="true")
      inspect(message.contains("/skills/b/SKILL.md"), content="true")
    }
    Ok(_) => fail("expected duplicate skill error")
  }
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].contains("broken/SKILL.md"), content="true")
}

///|
async test "recommendation use case prepares and decodes through a host" {
  let skill = @core.Skill::{ name: "demo", description: "test", path: "/demo", }
  let mut calls = 0
  let send : async (@core.ClassifierRequest) -> @core.ClassifierResponse = request => {
    calls += 1
    inspect(request.path, content="/v1/classify")
    inspect(request.body.contains("Task: test app"), content="true")
    {
      status: 200,
      body: "{\"results\":[{\"label\":\"directly applicable to the explicit user request\",\"confidence\":0.9,\"scores\":{\"directly applicable to the explicit user request\":0.8}}]}",
    }
  }
  let result = @core.recommend(send, [skill], "test app").unwrap()
  inspect(result.length(), content="1")
  inspect(result[0].skill.name, content="demo")
  inspect(calls, content="1")
  inspect(@core.recommend(send, [], "test app").unwrap().length(), content="0")
  inspect(calls, content="1")
}
