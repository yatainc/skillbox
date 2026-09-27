///|
test "front matter and search" {
  let browser = @core.parse_skill(
    "/root/.agents/skills/browser/SKILL.md", "---\nname: agent-browser\ndescription: Automate browser testing and screenshots.\n---\n# Body\n",
  ).unwrap()
  let moonbit = @core.parse_skill(
    "/root/.agents/skills/moonbit/SKILL.md", "---\nname: 'moonbit-guide'\ndescription: 'Write MoonBit code.'\n---\n",
  ).unwrap()
  inspect(browser.name, content="agent-browser")
  inspect(moonbit.description, content="Write MoonBit code.")
  let skills = [browser, moonbit]
  inspect(@core.search(skills, "BROWSER").length(), content="1")
  inspect(@core.search(skills, "code")[0].name, content="moonbit-guide")
  inspect(
    @core.recommendation_inputs(skills, "test web apps")[0],
    content="Task: test web apps\nSkill: agent-browser\nDescription: Automate browser testing and screenshots.",
  )
}

///|
test "malformed front matter is ignored" {
  inspect(
    @core.parse_skill("bad", "name: x\ndescription: y") is None,
    content="true",
  )
  inspect(@core.parse_skill("bad", "---\nname: x\n---") is None, content="true")
}
