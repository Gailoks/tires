using Tires.Primitives;
namespace Tires.Storage;
public interface IStoragePlanner
{
	public (List<FileEntry> SortedFiles, List<int> Boundaries) Distribute(List<FileEntry> allFiles);
	public long[] Sizes { get; set; }

}