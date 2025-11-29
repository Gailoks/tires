using Mono.Unix.Native;
namespace Tires.Primitives;

public record struct FileEntryPathInfo(
    string Path,
    int OwnerUid,
    int GroupGid,
	int Mode
);

public record struct FileEntry(
    List<FileEntryPathInfo> Paths,
    ulong Inode,
    long Size,
    int TierIndex
);