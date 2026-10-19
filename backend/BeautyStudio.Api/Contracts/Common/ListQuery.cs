using Microsoft.EntityFrameworkCore;

namespace BeautyStudio.Api.Contracts.Common;

public sealed class ListQuery
{
    public string? Search { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public bool? Active { get; set; }
    public int? CategoryId { get; set; }
    public string? Status { get; set; }
    public DateOnly? From { get; set; }
    public DateOnly? To { get; set; }
}

public static class Paging
{
    public static async Task<PagedResponse<T>> PageAsync<T>(this IQueryable<T> source, ListQuery query, CancellationToken ct)
    {
        if (query.From.HasValue && query.To.HasValue && query.To < query.From) throw new BeautyStudio.Api.Exceptions.BusinessException("Datum završetka mora biti nakon datuma početka.");
        var page = Math.Clamp(query.Page, 1, 100000);
        var size = Math.Clamp(query.PageSize, 1, 100);
        var count = await source.CountAsync(ct);
        var items = await source.Skip((page - 1) * size).Take(size).ToListAsync(ct);
        return new PagedResponse<T>(count, page, size, items);
    }
}
