using Tires.Storage;
using Tires.Primitives;
namespace Tires.Storage;

public interface ITierMover
{
	public bool MoveFile(FileEntry file, int TierId);

	public void ApplyPlan(List<FileEntry> files, List<int> indexes);
}