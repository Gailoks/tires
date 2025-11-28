using Microsoft.Extensions.Logging;
using Tires.Primitives;
using System.Runtime.InteropServices;

namespace Tires.Storage;

public class TierScanner : ITierScanner
{
	private readonly string _path;
	private readonly int _tierIndex;
	private readonly ILogger _logger;
	private readonly Dictionary<long, FileEntry> _files = new();

	public TierScanner(ILogger logger, int tierIndex, string path)
	{
		_logger = logger;
		_tierIndex = tierIndex;
		_path = path;
	}

	public async Task<List<FileEntry>> Scan()
	{
		var stack = new Stack<string>();
		stack.Push(_path);

		while (stack.Count > 0)
		{
			string dir = stack.Pop();

			IEnumerable<string> dirs;
			IEnumerable<string> files;

			try
			{
				dirs = Directory.EnumerateDirectories(dir);
				files = Directory.EnumerateFiles(dir);
			}
			catch (Exception ex)
			{
				_logger.LogWarning(ex, "Cannot read directory {Dir}", dir);
				continue;
			}

			foreach (var d in dirs)
			{
				try
				{
					var attr = File.GetAttributes(d);
					if (!attr.HasFlag(FileAttributes.ReparsePoint))
						stack.Push(d);
					else
						await AddFile(d); 
				}
				catch
				{
				}
			}

			foreach (var f in files)
			{
				await AddFile(f);
			}
		}

		return _files.Values.ToList();
	}

	private async Task AddFile(string path)
	{
		await Task.Yield();

		FileInfo fi;
		try
		{
			fi = new FileInfo(path);
		}
		catch
		{
			return;
		}

		long inode = GetInode(fi);
		long size = fi.Exists ? fi.Length : 0;

		if (_files.TryGetValue(inode, out var existing))
		{
			existing.Paths.Add(path);
			return;
		}

		var entry = new FileEntry(
			Paths: new List<string> { path },
			Inode: inode,
			Size: size,
			TierIndex: _tierIndex
		);

		_files[inode] = entry;

		_logger.LogDebug("Tier {Tier}: {File} (inode={Inode})", _tierIndex, path, inode);
	}


	private static long GetInode(FileInfo fi)
	{
		if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
		{
			var st = new Mono.Unix.Native.Stat();
			if (Mono.Unix.Native.Syscall.stat(fi.FullName, out st) == 0)
				return (long)st.st_ino;
		}

		return fi.FullName.GetHashCode();
	}
}
