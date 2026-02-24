# Tires — Документация

## Конфигурация

### Основные опции

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "LogPath": "/var/log/tires/tires.log",
    "TemporaryPath": "tmp",
    "RunInterval": "hourly",
    "ProcessPriority": 2,
    "Tiers": [
        {
            "target": 90,
            "path": "/mnt/ssd",
            "MockCapacity": 1073741824
        }
    ],
    "FolderRules": [
        {
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        }
    ]
}
```

### Описание опций

| Опция | Тип | По умолчанию | Описание |
|-------|-----|--------------|----------|
| `IterationLimit` | int | 20 | Макс. итераций перемещения за запуск |
| `LogLevel` | string | "Information" | Debug, Information, Warning, Error |
| `LogPath` | string | "/var/log/tires/tires.log" | Путь к файлу лога |
| `TemporaryPath` | string | "tmp" | Временная папка для перемещений |
| `RunInterval` | string | "hourly" | Частота запуска (minutely, hourly, daily, weekly, monthly или формат systemd calendar) |
| `ProcessPriority` | int | 2 | Приоритет процесса: -20 (высший) до 19 (низший). По умолчанию 2 = Idle |
| `Tiers` | array | требуется | Определение уровней хранения |
| `FolderRules` | array | null | Правила сортировки/исключения |

### Опции уровней

| Опция | Тип | Описание |
|-------|-----|----------|
| `target` | int | Процент заполнения (90 = 90% макс) |
| `path` | string | Абсолютный путь к уровню |
| `MockCapacity` | int | **Тестирование** — фиктивная ёмкость в байтах |

### Опции правил

| Опция | Тип | Описание |
|-------|-----|----------|
| `PathPrefix` | string | Путь папки для сопоставления |
| `Priority` | int | Чем выше = обрабатывается первым |
| `RuleType` | string | `Size`, `Name`, `Time`, `Ignore` |
| `Reverse` | bool | Обратный порядок сортировки |
| `Pattern` | string | Шаблон для правила Name |
| `TimeType` | string | `Access`, `Modify`, `Change` |

---

## Правила

### IgnoreRule — Исключить папки

Файлы в указанных папках **никогда не перемещаются**:

```json
{"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"}
```

### SizeRule — Сортировка по размеру

```json
{"PathPrefix": "videos", "Priority": 50, "RuleType": "Size", "Reverse": true}
```

| Reverse | Порядок | Файлы на SSD | Файлы на HDD |
|---------|---------|--------------|--------------|
| `false` (по умолчанию) | Малые → Большие | **Малые файлы** | Большие файлы |
| `true` | Большие → Малые | **Большие файлы** | Малые файлы |

**Примеры:**

- `"Reverse": false` — Малые файлы → **SSD**, большие → HDD
- `"Reverse": true` — Большие файлы → **SSD**, малые → HDD

### NameRule — Сортировка по паттерну

```json
{"PathPrefix": "media", "Priority": 30, "RuleType": "Name", "Pattern": ".mp4"}
```

| Reverse | Балл совпадения | Балл несовпадения | Файлы на SSD | Файлы на HDD |
|---------|-----------------|-------------------|--------------|--------------|
| `false` (по умолчанию) | 1 | 0 | **Несовпадающие** | Совпадающие |
| `true` | -1 | 0 | **Совпадающие** | Несовпадающие |

**Примеры:**

- `"Reverse": false` — Несовпадающие → **SSD**, совпадающие → HDD
- `"Reverse": true` — Совпадающие → **SSD**, несовпадающие → HDD

### TimeRule — Сортировка по времени

```json
{"PathPrefix": "documents", "Priority": 20, "RuleType": "Time", "TimeType": "Modify"}
```

| TimeType | Описание |
|----------|----------|
| `Access` | Время последнего доступа |
| `Modify` | Время последнего изменения |
| `Change` | Время последнего изменения метаданных |

| Reverse | Порядок | Файлы на SSD | Файлы на HDD |
|---------|---------|--------------|--------------|
| `false` (по умолчанию) | Старые → Новые | **Старые файлы** | Новые файлы |
| `true` | Новые → Старые | **Новые файлы** | Старые файлы |

**Примеры:**

- `"Reverse": false` — Старые файлы → **SSD**, новые → HDD
- `"Reverse": true` — Новые файлы → **SSD**, старые → HDD

---

## Systemd

### Включить автоматический запуск

**Пакеты (.deb/.rpm):** Файлы устанавливаются автоматически.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tires.timer
```

**Ручная установка (tar.gz):**

```bash
sudo cp packaging/systemd/tires.service /lib/systemd/system/
sudo cp packaging/systemd/tires.timer /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tires.timer
```

### Настроить интервал

Отредактируйте `/etc/tires/storage.json`:

```json
{"RunInterval": "daily"}
```

Поддерживаемые значения:
- `minutely`, `hourly` (по умолчанию), `daily`, `weekly`, `monthly`
- Формат systemd calendar (например, `*-*-* 02:00:00` для ежедневного запуска в 2 AM)

Применить конфигурацию:

```bash
sudo /usr/bin/tires-setup-timer.sh
```

### Изменить расписание

Создайте `/etc/systemd/system/tires.timer.d/override.conf`:

```ini
[Timer]
OnCalendar=*-*-* 00/6:00:00  # Каждые 6 часов
Persistent=true
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart tires.timer
```

### Безопасность

Служба systemd включает усиление безопасности:

- `NoNewPrivileges=true` — Запрет повышения привилегий
- `ProtectSystem=strict` — Системные директории только для чтения
- `ProtectHome=read-only` — Домашние директории только для чтения
- `PrivateTmp=true` — Изолированная временная директория

---

## Решение проблем

### Файлы не перемещаются

```bash
# Проверить логи
journalctl -u tires.service -f

# Проверить конфигурацию
sudo tires /etc/tires/storage.json

# Проверить пути
ls -la /mnt/ssd /mnt/hdd
```

### Ошибка доступа

```bash
sudo tires /etc/tires/storage.json
ls -la /etc/tires/storage.json
```

### Проблемы службы

```bash
sudo systemctl status tires.service tires.timer
sudo journalctl -u tires.service -n 50
sudo systemctl restart tires.timer
```

### Timer не работает

```bash
systemctl list-timers | grep tires
sudo systemctl enable --now tires.timer
```

---

## Смотрите также

- **[Примеры](../examples/README.md)** — Примеры конфигурации
- **[Тесты](TESTS.md)** — Документация тестов
- **[English Documentation](README.md)** — English documentation
