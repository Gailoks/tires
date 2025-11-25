using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Tires.Config;
using Tires.Primitives;

namespace Tires.Storage
{
	public class TierMover : ITierMover
	{
		private readonly List<Tier> _tiers;
		private readonly ILogger<TierMover> _logger;

		private readonly int IterationLimit;

		public TierMover(Configuration configuration, ILogger<TierMover> logger)
		{
			_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();
			_logger = logger;
			IterationLimit = configuration.IterationLimit;
		}
		public bool HasFile(int TierIndex, FileEntry file) => file.TierIndex == TierIndex;

		public bool CanFit(Tier tier, FileEntry file) => file.Size < tier.Free;

		public bool MoveFile(FileEntry file, int targetTierIndex)
		{
			Tier source = _tiers[file.TierIndex];
			Tier target = _tiers[targetTierIndex];

			if (HasFile(targetTierIndex, file))
			{
				_logger.LogInformation("Tier {TierPath} already contains file {FilePath}", target._path, file.Path);
				return true;
			}
			if (!CanFit(target, file))
			{
				_logger.LogDebug("Tier {TierPath} cannot fit file {FilePath} due to target limit", target._path, file.Path);
				return false;
			}

			try
			{
				string relativePath = Path.GetRelativePath(source._path, file.Path);
				string targetPath = Path.Combine(target._path, relativePath);

				string? targetDir = Path.GetDirectoryName(targetPath);
				if (targetDir != null)
					Directory.CreateDirectory(targetDir);

				string tempPath = targetPath + ".tmp";

				File.Copy(file.Path, tempPath, overwrite: true);

				target.Free -= file.Size;

				File.Move(tempPath, targetPath, overwrite: true);

				File.Delete(file.Path);

				source.Free += file.Size;


				_logger.LogInformation("Moved {SourcePath} → {TargetPath}", file.Path, targetPath);
				return true;
			}
			catch (Exception ex)
			{
				_logger.LogWarning(ex, "Failed to move {SourcePath} → {TargetPath}", file.Path, file.Path);
				return false;
			}
		}


		public void ApplyPlan(List<FileEntry> files, List<int> indexes)
		{
			_logger.LogInformation("Total files to distribute: {Count}", files.Count);
			int iterations = 1;
			int startIndex = 0;
			int alpha = 0;

			while (iterations > 0 && alpha != IterationLimit)
			{
				for (int tierIdx = 0; tierIdx < _tiers.Count; tierIdx++)
				{
					int endIndex = indexes[tierIdx];

					for (int i = startIndex; i <= endIndex && i < files.Count; i++)
					{
						if (!MoveFile(files[i], tierIdx))
						{
							iterations += 1;
							_logger.LogDebug($"Cannot move file {files[i].Path} now, will retry in next iteration");
							break;
						}
						else
						{
							files[i].TierIndex = tierIdx;
						}
					}
					startIndex = endIndex + 1;
				}
				startIndex = 0;
				iterations--;
				alpha++;
			}

			_logger.LogInformation("Distribution complete");
		}
	}
}
