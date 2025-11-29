using Microsoft.Extensions.Logging;
using Tires.Primitives;
using System.Runtime.InteropServices;
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

            // push subdirectories
            foreach (var d in dirs)
            {
                try
                {
                    var attr = File.GetAttributes(d);
                    if (!attr.HasFlag(FileAttributes.ReparsePoint))
                        stack.Push(d);
                }
                catch { }
            }

            // process files
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

        try
        {
            var st = new Stat();
            if (Syscall.stat(path, out st) != 0)
            {
                _logger.LogWarning("stat() failed on {File}", path);
                return;
            }

            // file type mask
            FilePermissions type = st.st_mode & FilePermissions.S_IFMT;

            // skip EVERYTHING except regular files
            switch (type)
            {
                case FilePermissions.S_IFREG:
                    break;

                case FilePermissions.S_IFLNK:
                    _logger.LogDebug("Skipping symlink {File}", path);
                    return;

                case FilePermissions.S_IFIFO:
                    _logger.LogDebug("Skipping FIFO {File}", path);
                    return;

                case FilePermissions.S_IFSOCK:
                    _logger.LogDebug("Skipping socket {File}", path);
                    return;

                case FilePermissions.S_IFCHR:
                case FilePermissions.S_IFBLK:
                    _logger.LogDebug("Skipping device node {File}", path);
                    return;

                case FilePermissions.S_IFDIR:
                    // Should never happen here
                    return;

                default:
                    _logger.LogDebug("Skipping unsupported file type {File}", path);
                    return;
            }

            ulong inode = st.st_ino;
            long size = st.st_size;

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

            _logger.LogDebug(
                "Tier {Tier}: {File} Size={Size} inode={Inode}",
                _tierIndex, path, size, inode
            );
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to add file {File}", path);
        }
    }
}
