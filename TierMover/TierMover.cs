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

	public TierMover(Configuration configuration, ILogger<TierMover> logger)
	{
		_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();

		_logger = logger;
		_iterationLimit = configuration.IterationLimit;
	}

	private bool CanFit(Tier tier, FileEntry file) => file.Size <= tier.Free;
	public bool MoveFile(FileEntry file, int targetTier)
	{
		int sourceTier = file.TierIndex;
		_logger.LogDebug("Moving inode: {Inode}\n files: {File}",file.Inode, string.Join(", ",file.Paths));

		if (sourceTier == targetTier)
		{
			_logger.LogDebug("File already in tier {TierIndex}", targetTier);
			return true;
		}

		Tier src = _tiers[sourceTier];
		Tier dst = _tiers[targetTier];

		if (!CanFit(dst, file))
		{
			_logger.LogDebug("Tier {TierPath} cannot fit inode={Inode}", dst._path, file.Inode);
			return false;
		}

		try
		{
			string srcMain = file.Paths[0];
			string relPath = Path.GetRelativePath(src._path, srcMain);
			string dstMainPath = Path.Combine(dst._path, relPath);

			Directory.CreateDirectory(Path.GetDirectoryName(dstMainPath)!);

			var srcInfo = new FileInfo(srcMain);

			string tmp = dstMainPath + ".tmp";
			File.Copy(srcMain, tmp, overwrite: true);

			File.Move(tmp, dstMainPath, true);

			for (int i = 1; i < file.Paths.Count; i++)
			{
				string originalRel = Path.GetRelativePath(src._path, file.Paths[i]);
				string dstPath = Path.Combine(dst._path, originalRel);
				Directory.CreateDirectory(Path.GetDirectoryName(dstPath)!);

				Syscall.link(dstMainPath, dstPath);
			}

			foreach (var oldPath in file.Paths)
			{
				if (File.Exists(oldPath))
					File.Delete(oldPath);
			}


			src.Free += file.Size;
			dst.Free -= file.Size;

			_logger.LogInformation("Moved files: {Files}\n inode: {Inode}\n from {Src} → {Dst}",string.Join(", ", file.Paths), file.Inode, src._path, dst._path);
			return true;
		}
		catch (Exception ex)
		{
			_logger.LogWarning(ex, "Failed to move files: {Files}\n inode: {Inode}\n from {Src} → {Dst}",string.Join(", ", file.Paths), file.Inode, src._path, dst._path);
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
