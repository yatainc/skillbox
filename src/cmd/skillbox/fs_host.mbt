///|
fn join_path(base : String, child : String) -> String {
  @path.Path::join(Path(base), Path(child)).to_string()
}

///|
/// Adapt the native async filesystem to the backend-neutral core port.
fn native_fs() -> @core.FsHost {
  {
    exists: path => @fs.exists(path),
    read_dir: path => @fs.readdir(path),
    kind: path => {
      match @fs.kind(path) {
        Directory => Directory
        Regular => Regular
        _ => Other
      }
    },
    realpath: path => @fs.realpath(path),
    read_file: path => @fs.read_file(path).text(),
    join: join_path,
  }
}

///|
/// Find the nearest Git project as a candidate skill discovery location.
async fn git_root(cwd : String) -> String? {
  let mut dir = @path.Path(cwd).resolve().to_string()
  for ;; {
    if @fs.exists(join_path(dir, ".git")) {
      return Some(dir)
    }
    let parent = @path.Path(dir).dirname().to_string()
    if parent == dir {
      return None
    }
    dir = parent
  }
}

///|
async fn discovery_roots() -> Array[String] {
  let roots_by_priority : Array[String] = []
  if @env.current_dir() is Some(cwd) {
    if git_root(cwd) is Some(root) {
      roots_by_priority.push(join_path(root, ".agents/skills"))
    }
  }
  if @env.get_env_var("HOME") is Some(home) {
    roots_by_priority.push(join_path(home, ".agents/skills"))
  }
  roots_by_priority
}
