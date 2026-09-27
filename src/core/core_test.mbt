///|
test "YAML front matter is isolated from Markdown body" {
  let skill = @core.parse_skill_checked(
    "project/SKILL.md", "---\nname: 'browser: helper'\ndescription: >-\n  Automate browser\n  testing and QA.\nhidden: true\n---\n# Body\nname: not-metadata\n",
  ).unwrap()
  inspect(skill.name, content="browser: helper")
  inspect(skill.description, content="Automate browser testing and QA.")
  inspect(skill.path, content="project/SKILL.md")
  let bom = @core.parse_skill_checked(
    "bom", "\u{feff}---\r\nname: sample\r\ndescription: text\r\n---\r\n",
  ).unwrap()
  inspect(bom.name, content="sample")
  let block = @core.parse_skill_checked(
    "block/SKILL.md", "---\nname: block\ndescription: |\n  first\n  ---\n  last\n---\n# body\n",
  ).unwrap()
  inspect(block.description.contains("last"), content="true")
  inspect(block.description.contains("---"), content="true")
  let bad = @core.parse_skill_checked(
    "bad/SKILL.md", "---\nname: x\nname: y\ndescription: z\n---",
  )
  inspect(bad is Err(_), content="true")
}

///|
test "project skill wins regardless of input ordering" {
  let home = @core.parse_skill(
    "home/a/SKILL.md", "---\nname: a\ndescription: home\n---",
  ).unwrap()
  let project = @core.parse_skill(
    "project/a/SKILL.md", "---\nname: a\ndescription: project\n---",
  ).unwrap()
  let other = @core.parse_skill(
    "home/b/SKILL.md", "---\nname: b\ndescription: other\n---",
  ).unwrap()
  let result = @core.merge_skills([[project], [other, home]]).unwrap()
  inspect(result.length(), content="2")
  inspect(result[0].path, content="project/a/SKILL.md")
  inspect(result[1].name, content="b")
  inspect(
    @core.get_skill(result, "a").unwrap().path,
    content="project/a/SKILL.md",
  )
  inspect(@core.get_skill(result, "A") is None, content="true")
  inspect(@core.get_skill(result, "absent") is None, content="true")
  let sorted = @core.merge_skills([
    [project],
    [
      other,
      home,
      @core.parse_skill("home/z", "---\nname: z\ndescription: z\n---").unwrap(),
    ],
  ]).unwrap()
  inspect(sorted.map(fn(s) { s.name }).join(","), content="a,b,z")
  let six = @core.merge_skills([
    [
      "fetch-url", "nix-setup", "web-search", "orchestrate", "agent-browser", "moonbit-agent-guide",
    ].map(fn(n) {
      @core.parse_skill(n, "---\nname: " + n + "\ndescription: test\n---").unwrap()
    }),
  ]).unwrap()
  inspect(
    six.map(fn(s) { s.name }).join(","),
    content="agent-browser,fetch-url,moonbit-agent-guide,nix-setup,orchestrate,web-search",
  )
  inspect(@core.merge_skills([[home, home]]) is Err(_), content="true")
  inspect(
    @core.merge_skills([[project], [home, home]]) is Err(_),
    content="true",
  )
  inspect(@core.merge_skills([]).unwrap().length(), content="0")
}

///|
test "classifier request is a transport-independent JSON POST" {
  let skill = @core.parse_skill(
    "x", "---\nname: browser\ndescription: Navigate and test websites.\n---",
  ).unwrap()
  let request = @core.classifier_request([skill], "test a website").unwrap()
  inspect(request.path, content="/v1/classify")
  inspect(request.content_type, content="application/json")
  let body = @json.parse(request.body)
  inspect(body is Object(_), content="true")
  inspect(request.body.contains("Task: test a website"), content="true")
  inspect(request.body.contains("Navigate and test websites."), content="true")
  inspect(
    request.body.contains(
      "not directly applicable to the explicit user request",
    ),
    content="true",
  )
  inspect(@core.classifier_request([], "test") is Err(_), content="true")
  inspect(@core.classifier_request([skill], "  ") is Err(_), content="true")
}

///|
test "classifier response distinguishes recommendations from uncertain results" {
  let skills = [
    @core.parse_skill(
      "a", "---\nname: browser\ndescription: browser automation\n---",
    ).unwrap(),
    @core.parse_skill(
      "b", "---\nname: accessibility\ndescription: accessibility audit\n---",
    ).unwrap(),
    @core.parse_skill("c", "---\nname: unrelated\ndescription: cooking\n---").unwrap(),
  ]
  let response : Json = {
    "results": [
      {
        "label": "directly applicable to the explicit user request",
        "confidence": 0.95,
        "scores": { "directly applicable to the explicit user request": 0.99 },
      },
      {
        "label": "directly applicable to the explicit user request",
        "confidence": 0.25,
        "scores": { "directly applicable to the explicit user request": 0.63 },
      },
      {
        "label": "not directly applicable to the explicit user request",
        "confidence": 0.99,
        "scores": { "directly applicable to the explicit user request": 0.01 },
      },
    ],
  }
  let body = response.stringify()
  let result = @core.classifier_response(skills, 200, body).unwrap()
  inspect(result.length(), content="2")
  inspect(result[0].skill.name, content="browser")
  inspect(result[1].skill.name, content="accessibility")
  inspect(result[1].confidence.unwrap(), content="0.25")
  inspect(
    @core.classifier_response(skills, 429, body) is Err(_),
    content="true",
  )
  inspect(
    @core.classifier_response(skills, 200, "{\"results\":[]}") is Err(_),
    content="true",
  )
  inspect(
    @core.classifier_response(skills, 200, "not json") is Err(_),
    content="true",
  )
}

///|
test "equal relevance uses deterministic lexical name order" {
  let z = @core.Skill::{ name: "z", description: "test", path: "/z", }
  let aa = @core.Skill::{ name: "aa", description: "test", path: "/aa", }
  let response : Json = {
    "results": [
      {
        "label": "directly applicable to the explicit user request",
        "confidence": 0.9,
        "scores": { "directly applicable to the explicit user request": 0.9 },
      },
      {
        "label": "directly applicable to the explicit user request",
        "confidence": 0.9,
        "scores": { "directly applicable to the explicit user request": 0.9 },
      },
    ],
  }
  let result = @core.classifier_response([z, aa], 200, response.stringify()).unwrap()
  inspect(result.map(fn(item) { item.skill.name }).join(","), content="aa,z")
}

///|
test "null classifier confidence is retained" {
  let skill = @core.parse_skill("x", "---\nname: x\ndescription: y\n---").unwrap()
  let response : Json = {
    "results": [
      {
        "label": "directly applicable to the explicit user request",
        "confidence": null,
        "scores": null,
      },
    ],
  }
  let result = @core.classifier_response([skill], 200, response.stringify()).unwrap()
  inspect(result.length(), content="1")
  inspect(result[0].confidence is None, content="true")
  inspect(result[0].relevance is None, content="true")
}
