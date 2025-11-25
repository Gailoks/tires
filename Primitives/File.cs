namespace Tires.Primitives;

public class FileEntry
{
    public required string Path { get; set; }
    public required long Size { get; set; }
    public required int TierIndex { get; set; }
}
