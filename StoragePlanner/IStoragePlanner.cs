using Tires.Primitives;
namespace Tires.Storage;
public interface IStoragePlanner
{
	public List<int> Distribute(List<FileEntry> allFiles);
	public long[] Sizes { get; set; }

}