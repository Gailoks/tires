using Microsoft.Extensions.Logging;

namespace Tires.Primitives;

public class Tier
{
	private readonly TierConfig _config;
	private long _free;
	private readonly long _space;
	private readonly long _allowed;

	public Tier(TierConfig config)
	{
		_config = config;
		var drive = new DriveInfo(Path.GetFullPath(_path)!);
		_free = drive.AvailableFreeSpace;
		_space = drive.TotalSize;
		_allowed = _space * Target / 100;
		var used = _space - _free;
		_free = _allowed - used;
	}

	public string _path => _config.Path;
	public int Target => _config.Target;

	public long Free { get => _free > _allowed ? _allowed : _free; set => _free = value; }
	public long Space { get => _space; }
	public long AllowedSpace { get => _allowed; }
}