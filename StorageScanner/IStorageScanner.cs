using Tires.Primitives; 
namespace Tires.Storage;

public interface IStorageScanner
{
	public List<FileEntry> GetSortedFiles();
	public long[] Sizes { get; }

}
