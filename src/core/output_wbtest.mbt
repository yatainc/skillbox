///|
test "table has name relevance path columns including empty results" {
  inspect(
    format_table([]),
    content="name\trelevance\tpath\n----\t---------\t----",
  )
  let rows = [
    OutputRow::{
      name: "browser",
      relevance: Some(0.99),
      path: "project/SKILL.md",
    },
  ]
  inspect(
    format_table(rows),
    content="name\trelevance\tpath\n----\t---------\t----\nbrowser\t0.99\tproject/SKILL.md",
  )
}

///|
test "JSON uses relevance number or null without a review marker" {
  let rows = [
    OutputRow::{ name: "browse", relevance: None, path: "/home/SKILL.md", },
    { name: "audit", relevance: Some(0.63), path: "/project/SKILL.md", },
  ]
  json_inspect(@json.parse(format_json(rows)), content=[
    { "name": "browse", "relevance": null, "path": "/home/SKILL.md" },
    { "name": "audit", "relevance": 0.63, "path": "/project/SKILL.md" },
  ])
}

///|
test "table escapes terminal controls while JSON preserves the values" {
  let skill = parse_skill_checked(
    "/demo/SKILL.md", "---\nname: \"\\u001b[2Jbad\"\ndescription: test\n---\n",
  ).unwrap()
  let row = OutputRow::{
    name: skill.name + "\t\n\r\u{0007}\u{007f}\u{009b}\u{202e}\u{2066}\u{2028}",
    relevance: None,
    path: "/tmp/\u{001b}[0m\nSKILL.md",
  }
  let table = format_table([row])
  inspect(
    table.contains(
      "\\u001B[2Jbad\\u0009\\u000A\\u000D\\u0007\\u007F\\u009B\\u202E\\u2066\\u2028",
    ),
    content="true",
  )
  inspect(table.contains("/tmp/\\u001B[0m\\u000ASKILL.md"), content="true")
  inspect(table.contains("\u{001b}"), content="false")
  inspect(table.contains("\u{0007}"), content="false")
  json_inspect(@json.parse(format_json([row])), content=[
    {
      "name": "\u{001b}[2Jbad\t\n\r\u{0007}\u{007f}\u{009b}\u{202e}\u{2066}\u{2028}",
      "relevance": null,
      "path": "/tmp/\u{001b}[0m\nSKILL.md",
    },
  ])
}

///|
test "get returns the SKILL.md path or a JSON string" {
  let skill = Skill::{
    name: "demo",
    description: "test",
    path: "/some place/\u{001b}[2J/SKILL.md",
  }
  inspect(
    format_skill_path(skill, false),
    content="/some place/\u{001b}[2J/SKILL.md",
  )
  json_inspect(
    @json.parse(format_skill_path(skill, true)),
    content="/some place/\u{001b}[2J/SKILL.md",
  )
}

///|
test "rendering displays first five ranked matches without re-sorting" {
  let recommendations : Array[Recommendation] = []
  for i in 0..<7 {
    let i = 6 - i
    let name = "skill-\{i}"
    let skill = Skill::{ name, description: "test", path: "/\{name}/SKILL.md", }
    let item = Recommendation::{
      skill,
      confidence: if i == 6 {
        Some(0.2)
      } else {
        Some(0.9)
      },
      relevance: Some(i.to_double() / 10.0),
    }
    recommendations.push(item)
  }
  let rows = rows_from_recommendations(recommendations)
  inspect(rows.length(), content="5")
  inspect(
    rows.map(fn(row) { row.name }).join(","),
    content="skill-6,skill-5,skill-4,skill-3,skill-2",
  )
  inspect(rows[0].relevance.unwrap(), content="0.6")
}
