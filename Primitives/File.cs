using Mono.Unix.Native;
namespace Tires.Primitives;

public record struct FileEntry(
    List<string> Paths, // Relative paths
    ulong Inode,
    long Size,
    int TierIndex,
	int OwnerUid,
    int GroupGid,
	FilePermissions Mode,
	Timespec AccessTime,   // A – last access
	Timespec ModifyTime,   // M – last data modification
	Timespec ChangeTime   // C – last metadata change
);
// Goal is keep most information about file
//   File: tires.log
//   Size: 20532320  	Blocks: 40104      IO Block: 4096   regular file // Kept size
// Device: 8,2	Inode: 1308235     Links: 1 // Kept (device not used) 
// Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)  // Kept
// Access: 2025-12-13 15:12:37.096707865 +0300 // Kept
// Modify: 2025-12-13 12:01:10.591331586 +0300 // Kept
// Change: 2025-12-13 12:01:10.591331586 +0300 // Kept
//  Birth: 2025-12-05 00:00:01.864149562 +0300	// Can not be accessed