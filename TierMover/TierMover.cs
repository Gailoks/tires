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
			string srcMain = file.Paths[0];
			string relPath = Path.GetRelativePath(src._path, srcMain);
			string dstMainPath = Path.Combine(dst._path, relPath);

			Directory.CreateDirectory(Path.GetDirectoryName(dstMainPath)!);

			string tmpDir = Path.Combine(dst._path, _tmpDir);
			Directory.CreateDirectory(tmpDir);
			string tmpFile = Path.Combine(tmpDir, Guid.NewGuid().ToString() + ".tmp");

			// Copy file content
			File.Copy(srcMain, tmpFile, overwrite: true);

			// Move to destination FIRST
			File.Move(tmpFile, dstMainPath, true);

			// THEN preserve ownership and permissions (must be after move!)
			if (file.Paths.Count > 0)
			{
				// Set ownership (uid/gid)
				Syscall.chown(dstMainPath, file.OwnerUid, file.GroupGid);
				// Set permissions (mode)
				Syscall.chmod(dstMainPath, file.Mode);
				// Set timestamps (access and modify time) - convert Timespec to Timeval
				Syscall.utimes(dstMainPath, new[] {
					new Timeval() { tv_sec = file.AccessTime.tv_sec, tv_usec = file.AccessTime.tv_nsec / 1000 },
					new Timeval() { tv_sec = file.ModifyTime.tv_sec, tv_usec = file.ModifyTime.tv_nsec / 1000 }
				});
			}

			// Recreate hardlinks for additional paths
			for (int i = 1; i < file.Paths.Count; i++)
			{
				string originalRel = Path.GetRelativePath(src._path, file.Paths[i]);
				string dstPath = Path.Combine(dst._path, originalRel);
				Directory.CreateDirectory(Path.GetDirectoryName(dstPath)!);
				Syscall.link(dstMainPath, dstPath);
			}

			// Remove old files
			foreach (var oldPath in file.Paths)
				if (File.Exists(oldPath))
					File.Delete(oldPath);

			src.Free += file.Size;
			dst.Free -= file.Size;

			_logger.LogInformation(
				"Moved {FileCount} files (inode: {Inode}) from Tier {SourceTier} to Tier {TargetTier}",
				file.Paths.Count, file.Inode, sourceTier, targetTier);
			_logger.LogDebug("  Paths: {Paths}", string.Join(", ", file.Paths));
			_logger.LogDebug("  Mode: {Mode}, Owner: {Owner}, Group: {Group}", file.Mode, file.OwnerUid, file.GroupGid);

			return true;
		}
		catch (Exception ex)
		{
			_logger.LogWarning(
				ex,
				"Failed to move {FileCount} files (inode: {Inode}) from Tier {SourceTier} to Tier {TargetTier}",
				file.Paths.Count, file.Inode, sourceTier, targetTier);
			_logger.LogDebug("  Paths: {Paths}", string.Join(", ", file.Paths));
			return false;
		}
	}



	public void ApplyPlan(List<FileEntry> fileEntries, List<int> boundaries)
	{
		_logger.LogInformation("Starting file move operation");
		_logger.LogInformation("Total files to process: {Count}", fileEntries.Count);

		var files = fileEntries;
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

		_logger.LogInformation("File move operation completed after {Iterations} iterations", iterations);
		if (iterations >= _iterationLimit)
			_logger.LogWarning("Iteration limit ({Limit}) reached, some files may not have been moved", _iterationLimit);
	}

}
