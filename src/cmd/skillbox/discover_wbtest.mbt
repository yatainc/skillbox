///|
async test "native discovery follows skill symlinks without cycling" {
  let root = "_build/skillbox-native-discover-test"
  if @fs.exists(root) {
    @fs.rmdir(root, recursive=true)
  }
  let target = join_path(root, "actual")
  let skills = join_path(root, ".agents/skills")
  @fs.mkdir(target, recursive=true)
  @fs.mkdir(join_path(skills, "broken"), recursive=true)
  @fs.mkdir(join_path(root, ".git"))
  @fs.write_file(
    join_path(target, "SKILL.md"),
    "---\nname: linked\ndescription: from symlink\n---\n",
  )
  let physical_target = @fs.realpath(target)
  @fs.write_file(join_path(skills, "broken/SKILL.md"), "missing front matter")
  @fs.symlink(join_path(skills, "linked"), target=physical_target)
  @fs.symlink(join_path(target, "loop"), target=physical_target)
  let result = @core.load_skills(native_fs(), [skills])
  let found = result.skills.unwrap()
  inspect(found.length(), content="1")
  inspect(found[0].name, content="linked")
  inspect(result.diagnostics.length(), content="1")
  inspect(
    git_root(target).unwrap().has_suffix("/skillbox-native-discover-test"),
    content="true",
  )
  @fs.rmdir(root, recursive=true)
}
