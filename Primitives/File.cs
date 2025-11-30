using Mono.Unix.Native;
namespace Tires.Primitives;

public record struct FileEntry(
    List<string> Paths,
    ulong Inode,
    long Size,
    int TierIndex,
	int OwnerUid,
    int GroupGid,
	int Mode
);