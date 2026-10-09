#!/usr/bin/env bash
set -e

# Аргументы: API_URL MODEL [API_KEY] [FILE_PATH]
API_URL="${1:-http://localhost:11434/v1/chat/completions}"
MODEL="${2:-gemma4:12b}"
API_KEY="${3:-}"
FILE_PATH="${4:-}"

# Чтение файла или stdin
if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    CODE="$(cat "$FILE_PATH")"
else
    CODE="$(cat)"
    FILE_PATH="(stdin)"
fi

if [ -z "$CODE" ]; then
    echo "No requirements text provided"
    exit 1
fi

echo "===== AI REVIEW (LOCAL) ====="
echo "API: $API_URL"
echo "Model: $MODEL"
echo "File: $FILE_PATH"
echo "=============================="
echo ""

# Генерируем JSON и отправляем запрос через Python
python3 - "$API_URL" "$MODEL" "$API_KEY" "$FILE_PATH" <<'PYEOF'
import json, sys, subprocess

api_url = sys.argv[1]
model = sys.argv[2]
api_key = sys.argv[3]
file_path = sys.argv[4]

# Читаем текст требований из stdin
code = sys.stdin.read()

prompt = f"""### РОЛЬ
Ты — старший бизнес-аналитик и эксперт по системному анализу с 15-летним опытом
в области разработки десктопных приложений (Windows). Ты специализируешься
на аудите и верификации требований по стандартам IEEE 830, ISO/IEC/IEEE 29148
и методологии INVEST. Ты умеешь находить скрытые дефекты в документации,
которые приводят к переделкам на этапе разработки и тестирования.

### ЗАДАЧА
Проанализируй предоставленный файл требований к десктопному приложению
и проведи его аудит на качество самих требований. Не оценивай архитектуру
или бизнес-идею — оценивай именно формулировки требований.

Проверь каждое требование по следующим критериям качества:

1. **Полнота** — все ли аспекты описаны, нет ли пропущенных сценариев.
2. **Непротиворечивость** — нет ли конфликтов между требованиями.
3. **Однозначность** — можно ли трактовать требование двояко.
4. **Проверяемость (верифицируемость)** — можно ли написать тест-кейс.
5. **Атомарность** — описывает ли требование одну функцию, а не несколько.
6. **Необходимость** — есть ли требование, без которого можно обойтись.
7. **Трассируемость** — есть ли ID и связи с бизнес-целями.
8. **Измеримость** — есть ли числовые метрики там, где они нужны
   (время отклика, объём данных, нагрузка).

### КОНТЕКСТ
- Тип приложения: десктопное (Windows).
- Целевая аудитория документа: команда разработки и QA.
- Файл требований: {file_path}

### ОГРАНИЧЕНИЯ
- НЕ переписывай требования «с нуля» — только указывай проблемы и предлагай
  конкретные формулировки-исправления.
- НЕ выдумывай требования, которых нет в файле, — работай только с тем,
  что предоставлено.
- НЕ давай общих советов — каждое замечание должно быть привязано к
  конкретному пункту/требованию.
- Если требование корректно — отметь как «OK» без лишних слов.
- Отвечай на языке документа.
- Не используй маркетинговые обороты, пиши сухо и по делу.

### ФОРМАТ ВЫВОДА

## 1. Сводка
- Всего требований: N
- Проблемных: M (X%)
- Критичных дефектов: K
- Общая оценка качества: [X/10]
- Главные 3 проблемы документа

## 2. Таблица аудита
| ID | Требование (кратко) | Критерий | Проблема | Критичность | Предлагаемое исправление |
|----|---------------------|----------|----------|-------------|--------------------------|
| ... | ... | ... | ... | 🔴/🟡/🟢 | ... |

## 3. Противоречия
Явные конфликты между требованиями (ID ↔ ID, в чём суть).

## 4. Топ-5 рекомендаций
Приоритизированный список действий по улучшению документа.

---
ТЕКСТ ФАЙЛА ТРЕБОВАНИЙ:
---

{code}"""

payload = {
    "model": model,
    "messages": [
        {"role": "user", "content": prompt}
    ],
    "stream": False
}

headers = {"Content-Type": "application/json"}
if api_key:
    headers["Authorization"] = f"Bearer {api_key}"

proc = subprocess.run(
    ["curl", "-s", "-X", "POST", api_url,
     "-H", "Content-Type: application/json"] +
     (["-H", f"Authorization: Bearer {api_key}"] if api_key else []) +
     ["-d", json.dumps(payload, ensure_ascii=False)],
    capture_output=True, text=True
)

try:
    data = json.loads(proc.stdout)

    # OpenAI format: choices[0].message.content
    if "choices" in data and data["choices"]:
        content = data["choices"][0].get("message", {}).get("content", "")
    # Ollama format: message.content
    elif "message" in data:
        content = data["message"].get("content", "")
    else:
        content = json.dumps(data, ensure_ascii=False, indent=2)

    # Убираем markdown-обёртку ``` ... ```
    import re
    content = re.sub(r"^```[a-z]*\n?", "", content)
    content = re.sub(r"\n?```$", "", content)
    print(content)

except json.JSONDecodeError:
    print(proc.stdout)

PYEOF
