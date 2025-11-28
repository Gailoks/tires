namespace Tires.Primitives;

public record struct FileEntry(List<string> Paths,long Inode,long Size, int TierIndex);
