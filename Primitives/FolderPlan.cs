namespace Tires.Primitives;

public record struct FolderPlan
(
    string PathPrefix,
    int Priority,
    IRule Rule,
    bool Reverse
);