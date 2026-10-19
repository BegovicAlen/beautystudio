namespace BeautyStudio.Api.Contracts.Common;

public sealed record PagedResponse<T>(int Total, int Page, int PageSize, IReadOnlyList<T> Items);
