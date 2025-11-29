using Microsoft.Extensions.Logging;
using Tires.Config;
using Mono.Unix.Native;
using Tires.Primitives;
namespace Tires.Storage;

public class TierMover : ITierMover
{
	private readonly List<Tier> _tiers;
	private readonly ILogger<TierMover> _logger;
	private readonly int _iterationLimit;
	private readonly string _tmpDir;

	public TierMover(Configuration configuration, ILogger<TierMover> logger)
	{
		_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();

		_logger = logger;
		_iterationLimit = configuration.IterationLimit;
		_tmpDir = configuration.TemporaryPath;
	}

	private bool CanFit(Tier tier, FileEntry file) => file.Size <= tier.Free;
	public bool MoveFile(FileEntry file, int targetTier)
	{
		int sourceTier = file.TierIndex;
		if (sourceTier == targetTier)
			return true;

		Tier src = _tiers[sourceTier];
		Tier dst = _tiers[targetTier];

		if (!CanFit(dst, file))
			return false;

		try
		{
			string srcMain = file.Paths[0].Path;
			string relPath = Path.GetRelativePath(src._path, srcMain);
			string dstMainPath = Path.Combine(dst._path, relPath);

			// создаем директории
			Directory.CreateDirectory(Path.GetDirectoryName(dstMainPath)!);

			// путь временного файла
			string tmpDir = Path.Combine(dst._path, _tmpDir);
			Directory.CreateDirectory(tmpDir);
			string tmpFile = Path.Combine(tmpDir, Guid.NewGuid().ToString() + ".tmp");

			// копируем в временный файл
			File.Copy(srcMain, tmpFile, overwrite: true);

			// восстанавливаем права и владельца, если есть
			if (file.Paths.Count > 0)
			{
				var info = file.Paths[0];
				Syscall.chmod(tmpFile, (Mono.Unix.Native.FilePermissions)info.Mode);
				Syscall.chown(tmpFile, info.OwnerUid, info.GroupGid);
			}

			// перемещаем в финальное место
			File.Move(tmpFile, dstMainPath, true);

			// создаем hardlink для остальных путей
			for (int i = 1; i < file.Paths.Count; i++)
			{
				string originalRel = Path.GetRelativePath(src._path, file.Paths[i].Path);
				string dstPath = Path.Combine(dst._path, originalRel);
				Directory.CreateDirectory(Path.GetDirectoryName(dstPath)!);
				Syscall.link(dstMainPath, dstPath);
			}

			// удаляем старые файлы
			foreach (var oldPath in file.Paths)
				if (File.Exists(oldPath.Path))
					File.Delete(oldPath.Path);

			src.Free += file.Size;
			dst.Free -= file.Size;

			_logger.LogInformation(
				"Moved files: {Files}\n inode: {Inode}\n from {Src} → {Dst}",
				string.Join(", ", file.Paths), file.Inode, src._path, dst._path);

			return true;
		}
		catch (Exception ex)
		{
			_logger.LogWarning(
				ex,
				"Failed to move files: {Files}\n inode: {Inode}\n from {Src} → {Dst}",
				string.Join(", ", file.Paths), file.Inode, src._path, dst._path);
			return false;
		}
	}



	public void ApplyPlan(List<FileEntry> fileEntries, List<int> boundaries)
	{
		var files = fileEntries;
		_logger.LogInformation("Total files to move: {Count}", files.Count);

		int totalFiles = files.Count;

		int[] targetTier = new int[totalFiles];
		int currentTier = 0;
		int start = 0;

		foreach (int end in boundaries)
		{
			for (int i = start; i <= end && i < totalFiles; i++)
				targetTier[i] = currentTier;

			start = end + 1;
			currentTier++;
		}

		int iterations = 0;

		while (iterations < _iterationLimit)
		{
			bool progress = false;

			for (int i = 0; i < files.Count; i++)
			{
				int desired = targetTier[i];

				if (files[i].TierIndex == desired)
					continue;

				if (MoveFile(files[i], desired))
				{
					files[i] = files[i] with { TierIndex = desired };
					progress = true;
				}
			}

			if (!progress)
				break;

			iterations++;
		}

		_logger.LogInformation("Moving completed after {Iterations} iterations", iterations);
	}

}
