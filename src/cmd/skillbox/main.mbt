///|
async fn load_skills() -> Array[@core.Skill] {
  let roots_by_priority = discovery_roots()
  let result = @core.load_skills(native_fs(), roots_by_priority)
  for message in result.diagnostics {
    eprintln(message)
  }
  match result.skills {
    Ok(skills) => skills
    Err(message) => fail(message)
  }
}

///|
async fn recommend(
  skills : Array[@core.Skill],
  query : String,
) -> Array[@core.Recommendation] {
  let base_url = match @env.get_env_var("SKILLBOX_CLASSIFIER_BASE_URL") {
    Some(url) => url.trim().to_owned()
    None => "https://classifier.dev"
  }
  let result = @async.with_timeout(15000, () => {
    @core.recommend(classifier_sender(base_url), skills, query)
  }) catch {
    @async.TimeoutError => fail("classifier request timed out after 15 seconds")
    error => raise error
  }
  match result {
    Ok(recommendations) => recommendations
    Err(message) => fail(message)
  }
}

///|
async fn main {
  let args = match parse_args(@env.args()) {
    Ok(args) => args
    Err(message) => fail(message)
  }
  let skills = load_skills()
  let output = match args.command {
    List => @core.format_skills(skills, args.as_json)
    Get(name) =>
      match @core.get_skill(skills, name) {
        Some(skill) => @core.format_skill_path(skill, args.as_json)
        None => fail("skill not found: " + name)
      }
    Search(query) =>
      @core.format_skills(@core.search(skills, query), args.as_json)
    Recommend(query) =>
      @core.format_recommendations(recommend(skills, query), args.as_json)
  }
  println(output)
}
