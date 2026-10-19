using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using BeautyStudio.Api.Exceptions;

namespace BeautyStudio.Api.Data;

public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Unhandled request error. Trace identifier: {TraceIdentifier}", context.TraceIdentifier);
        var status = exception switch { NotFoundException => StatusCodes.Status404NotFound, BusinessException => StatusCodes.Status400BadRequest, UnauthorizedException => StatusCodes.Status401Unauthorized, _ => StatusCodes.Status500InternalServerError };
        var problem = new ProblemDetails { Status = status, Title = status == 500 ? "Došlo je do neočekivane greške." : exception.Message, Detail = status == 500 ? "Pokušajte ponovo kasnije." : null };
        context.Response.StatusCode = problem.Status.Value;
        await context.Response.WriteAsJsonAsync(problem, cancellationToken);
        return true;
    }
}
