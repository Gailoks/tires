using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;

namespace Tires;

public static class SimpleLogFormatterExtensions
{
    public static ILoggingBuilder AddSimpleFileLogger(
        this ILoggingBuilder builder,
        string logPath,
        LogLevel minLevel)
    {
        builder.Services.AddSingleton<ILoggerProvider>(sp =>
            new SimpleFileLoggerProvider(logPath, minLevel));
        return builder;
    }
}

public class SimpleFileLoggerProvider : ILoggerProvider
{
    private readonly string _logPath;
    private readonly LogLevel _minLevel;
    private readonly StreamWriter? _writer;
    private readonly object _lock = new();

    public SimpleFileLoggerProvider(string logPath, LogLevel minLevel)
    {
        _logPath = logPath;
        _minLevel = minLevel;

        // Create directory if it doesn't exist
        var directory = Path.GetDirectoryName(logPath);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            try
            {
                Directory.CreateDirectory(directory);
            }
            catch (UnauthorizedAccessException)
            {
                // Ignore if we don't have permission to create directory
            }
            catch (IOException)
            {
                // Ignore IO errors during directory creation
            }
        }

        // Open file for writing (overwrite on each run)
        try
        {
            _writer = new StreamWriter(logPath, append: false)
            {
                AutoFlush = true
            };
        }
        catch (UnauthorizedAccessException)
        {
            // Can't write to log file, ignore
            _writer = null;
        }
        catch (IOException)
        {
            // Can't write to log file, ignore
            _writer = null;
        }
    }

    public ILogger CreateLogger(string categoryName)
    {
        return new SimpleFileLogger(categoryName, _minLevel, _writer!, _lock);
    }

    public void Dispose()
    {
        _writer?.Dispose();
    }
}

public class SimpleFileLogger : ILogger
{
    private readonly string _categoryName;
    private readonly LogLevel _minLevel;
    private readonly StreamWriter _writer;
    private readonly object _lock;

    public SimpleFileLogger(
        string categoryName,
        LogLevel minLevel,
        StreamWriter writer,
        object lockObj)
    {
        _categoryName = categoryName;
        _minLevel = minLevel;
        _writer = writer;
        _lock = lockObj;
    }

    public IDisposable? BeginScope<TState>(TState state) where TState : notnull
    {
        return NullScope.Instance;
    }

    public bool IsEnabled(LogLevel logLevel)
    {
        return logLevel >= _minLevel;
    }

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (!IsEnabled(logLevel) || _writer == null)
            return;

        var message = formatter(state, exception);
        var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ");
        var level = logLevel.ToString().ToLower().PadRight(9); // "information" = 9 chars

        // Remove "Tires." prefix for cleaner output
        var shortCategory = _categoryName.StartsWith("Tires.")
            ? _categoryName.Substring(6)
            : _categoryName;

        lock (_lock)
        {
            try
            {
                _writer.WriteLine($"{timestamp}{level} {shortCategory}: {message}");
            }
            catch
            {
                // Ignore write errors (e.g. permission denied)
            }
        }
    }
}

internal sealed class NullScope : IDisposable
{
    public static NullScope Instance { get; } = new();
    private NullScope() { }
    public void Dispose() { }
}
