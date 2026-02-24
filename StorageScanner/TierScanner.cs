using Tires.Primitives;
using Microsoft.Extensions.Logging;
using Mono.Unix.Native;

namespace Tires.Storage;

public class TierScanner : ITierScanner
{
	private readonly string _path;
	private readonly int _tierIndex;
	private readonly ILogger _logger;
	private readonly Dictionary<ulong, FileEntry> _files = new();

	public TierScanner(ILogger logger, int tierIndex, string path)
	{
		_logger = logger;
		_tierIndex = tierIndex;
		_path = path;
	}

	public List<FileEntry> Scan()
	{
		var stack = new Stack<string>();
		stack.Push(_path);

		while (stack.Count > 0)
		{
			var dir = stack.Pop();

			string[] dirs;
			string[] files;

			try
			{
				dirs = Directory.GetDirectories(dir);
				files = Directory.GetFiles(dir);
			}
			catch (Exception ex)
			{
				_logger.LogDebug(ex, "Cannot read directory {Dir}", dir);
				continue;
			}

			for (int i = 0; i < dirs.Length; i++)
			{
				try
				{
					var attr = File.GetAttributes(dirs[i]);
					if (!attr.HasFlag(FileAttributes.ReparsePoint))
						stack.Push(dirs[i]);
				}
				catch { }
			}

			for (int i = 0; i < files.Length; i++)
				AddFile(files[i]);
		}

		return new List<FileEntry>(_files.Values);
	}

	private void AddFile(string path)
	{
		try
		{
			if (Syscall.stat(path, out var st) != 0)
			{
				_logger.LogDebug("stat() failed on {File}", path);
				return;
			}

			var type = st.st_mode & FilePermissions.S_IFMT;
			if (type != FilePermissions.S_IFREG)
			{
				_logger.LogDebug("Skipping non‑regular file {File}", path);
				return;
			}

			ulong inode = st.st_ino;
			long size = st.st_size;
			int uid = (int)st.st_uid;
			int gid = (int)st.st_gid;
			FilePermissions mode = st.st_mode;
			var atime = st.st_atim;
			var mtime = st.st_mtim;
			var ctime = st.st_ctim;

			if (_files.TryGetValue(inode, out var existing))
			{
				existing.Paths.Add(path);
				return;
			}

			var entry = new FileEntry(
				Paths: new List<string> { path },
				Inode: inode,
				Size: size,
				TierIndex: _tierIndex,
				OwnerUid: uid,
				GroupGid: gid,
				Mode: mode,
				AccessTime: atime,
				ModifyTime: mtime,
				ChangeTime: ctime
			);

			_files[inode] = entry;

			_logger.LogDebug(
				"Tier {Tier}: {File} Size={Size} inode={Inode} uid={Uid} gid={Gid} mode={Mode}",
				_tierIndex, path, size, inode, uid, gid, mode
			);
		}
		catch (Exception ex)
		{
			_logger.LogDebug(ex, "Failed to add file {File}", path);
		}
	}
}