///|
test "CRLF, extra front matter fields, and colons inside values" {
  let skill = @core.parse_skill(
    "project/.agents/skills/test/SKILL.md", "---\r\nname: example\r\ndescription: 'Inspect HTTP: headers'\r\nhidden: true\r\n---\r\n# description: not metadata\r\n",
  ).unwrap()
  inspect(skill.name, content="example")
  inspect(skill.description, content="Inspect HTTP: headers")
}

///|
test "Japanese substring search" {
  let skill = @core.parse_skill(
    "skill.md", "---\nname: 設計\ndescription: 日本語の設計を支援\n---\n",
  ).unwrap()
  inspect(@core.search([skill], "日本語").length(), content="1")
}
