# Настройка External Tool: Анализ требований (local_review.sh)

Скрипт запускает локальную или облачную LLM-модель для аудита файла требований по критериям качества (IEEE 830, ISO/IEC/IEEE 29148, INVEST).

---

## 1. Предварительные требования

- **Git for Windows** (для `bash.exe`) — [скачать](https://git-scm.com/download/win)
  - Путь: `C:\Program Files\Git\bin\bash.exe`
- **Python 3** — для генерации JSON-запроса
  - Путь: `C:\Python311\python.exe` (или любой другой)
- **Ollama** (для локальных моделей) — [скачать](https://ollama.com)
  - Запустить модель: `ollama run gemma4:12b`
- **API-ключ** (для облачных моделей: OpenAI, vLLM и т.д.)

---

## 2. Структура аргументов скрипта

```
local_review.sh <API_URL> <MODEL> [API_KEY] [FILE_PATH]
```

| Аргумент | Описание | Пример |
|----------|----------|--------|
| `API_URL` | URL API-эндпоинта | `http://localhost:11434/v1/chat/completions` |
| `MODEL` | Имя модели | `gemma4:12b` |
| `API_KEY` | Bearer-токен (если нужен) | `sk-...` или `""` если не нужен |
| `FILE_PATH` | Путь к файлу (опционально) | `$FilePath$` |

---

## 3. Настройка в PyCharm

### 3.1 Ollama (локальная модель)

Открой **File → Settings → Tools → External Tools** и добавь новый инструмент:

| Поле | Значение |
|------|----------|
| **Name** | `Review Requirements (Ollama)` |
| **Description** | Аудит файла требований через локальную LLM |
| **Program** | `C:\Program Files\Git\bin\bash.exe` |
| **Arguments** | `http://localhost:11434/v1/chat/completions gemma4:12b "" "$FilePath$"` |
| **Working directory** | `$ProjectFileDir$` |
| **Output filters** | `$(FILE_PATH):$(LINE):$(COLUMN)` |

### 3.2 OpenAI (gpt-4o)

| Поле | Значение |
|------|----------|
| **Name** | `Review Requirements (OpenAI)` |
| **Program** | `C:\Program Files\Git\bin\bash.exe` |
| **Arguments** | `https://api.openai.com/v1/chat/completions gpt-4o "sk-твой-ключ" "$FilePath$"` |
| **Working directory** | `$ProjectFileDir$` |

### 3.3 vLLM / LM Studio (OpenAI-совместимый API)

| Поле | Значение |
|------|----------|
| **Name** | `Review Requirements (vLLM)` |
| **Program** | `C:\Program Files\Git\bin\bash.exe` |
| **Arguments** | `http://localhost:8000/v1/chat/completions meta-llama/Meta-Llama-3-8B-Instruct "" "$FilePath$"` |
| **Working directory** | `$ProjectFileDir$` |

### 3.4 Любой другой OpenAI-совместимый API

Замени `API_URL`, `MODEL` и при необходимости `API_KEY`:

```
http://<host>:<port>/v1/chat/completions <model-name> "[api-key]" "$FilePath$"
```

---

## 4. Использование

1. Открой файл с требованиями (`.md`, `.txt`, `.docx` — любой текстовый формат).
2. Вызови инструмент:
   - **ПКМ → External Tools → Review Requirements (...)**
   - Или через меню **Tools → External Tools → Review Requirements (...)**

Результат анализа отобразится в окне External Tools.

---

## 5. Примеры запуска из терминала

```bash
# Ollama (локально)
bash local_review.sh http://localhost:11434/v1/chat/completions gemma4:12b "" requirements.md

# OpenAI
bash local_review.sh https://api.openai.com/v1/chat/completions gpt-4o "sk-..." requirements.md

# Из stdin (через pipe)
cat requirements.md | bash local_review.sh http://localhost:11434/v1/chat/completions gemma4:12b ""
```

---

## 6. Возможные проблемы

| Проблема | Решение |
|----------|---------|
| `bash: command not found` | Убедись, что Git for Windows установлен, и проверь путь к `bash.exe` |
| `Connection refused` | Проверь, запущен ли Ollama / vLLM / другой сервер |
| `401 Unauthorized` | Проверь API-ключ и его формат |
| `429 Rate Limit` | Подожди или увеличь лимиты на стороне API |
| `No response` | Проверь, что модель загрузилась и готова к запросам |

---

## 7. Критерии аудита

Скрипт проверяет требования по 8 критериям:

1. **Полнота** — все ли аспекты описаны
2. **Непротиворечивость** — нет ли конфликтов
3. **Однозначность** — нет ли двусмысленностей
4. **Проверяемость** — можно ли написать тест-кейс
5. **Атомарность** — одно требование = одна функция
6. **Необходимость** — нет ли избыточных требований
7. **Трассируемость** — есть ли ID и связи
8. **Измеримость** — есть ли числовые метрики
