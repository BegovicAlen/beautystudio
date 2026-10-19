namespace BeautyStudio.Api.Exceptions;

public sealed class BusinessException(string message) : Exception(message);
