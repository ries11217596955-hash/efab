# OWNER_SCHOOL_RUNBOOK_V1

Status: ACTIVE_OWNER_RUNBOOK
Created: 2026-07-15T15:53:33+04:00
Layer: Owner / GPT operator control
Depends on: operations/school/OWNER_SCHOOL_CONTROL_CONTRACT_V1.md

## 1. Что это

Это пульт управления School для нас.

Не теория. Не паспорт органа агента. Не body-map.

Назначение:

```text
Owner говорит, что хочет сделать со School.
GPT выбирает безопасный режим,
даёт одну понятную команду или выполняет её после preflight,
собирает proof,
и говорит, что доказано / не доказано.
```

## 2. Главный вход

Всегда использовать один Owner-facing вход:

```powershell
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live> -Topics <AUTO|topic1,topic2>
```

Проверка политики входа:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
```

Если validator не PASS — School не запускать.

## 3. Быстрый словарь Owner-команд

### “Проверь School”

Действие:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
```

Результат должен сказать:

```text
PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2
OWNER_ENTRYPOINT = operations/school/run_agent_school.ps1
OWNER_FIELDS = Count, Mode, Topics
```

### “Запусти маленький тест”

Перед этим обязательно сделать preflight из раздела 4.

Команда-кандидат:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/run_agent_school.ps1 -Count 25 -Mode Test -Topics AUTO
```

Статус после запуска:

```text
Test run only
no live readiness claim
proof/report required
```

### “Подготовь Live”

Не запускать сразу.

Сначала собрать Live gate:

```text
repo clean/synced
no duplicate School / producer / digest process
active memory exists and is protected
last bounded Test proof PASS
disk/log path known
stop/resume plan exists
Owner route authority explicit
```

Если хотя бы один пункт не доказан — `BLOCKED_LIVE_GATE`.

### “Что сейчас происходит?”

Только observe:

```powershell
Get-CimInstance Win32_Process | Where-Object {
  $cmd=$_.CommandLine
  if (-not $cmd) { $cmd='' }
  $_.Name -like '*run_agent_school*' -or
  $cmd -like '*run_agent_school*' -or
  $cmd -like '*exact_count_cycle*' -or
  $cmd -like '*codex_warehouse*' -or
  $cmd -like '*absorb_atom_file*' -or
  $cmd -like '*digest*'
} | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List
```

Не останавливать процессы без конкретного PID/route reason.

## 4. Обязательный preflight перед любым запуском

```powershell
git status --short --untracked-files=all
git fetch origin main
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
git rev-list --left-right --count HEAD...origin/main
```

Требование:

```text
git status = clean
branch = main или явно разрешённая ветка
origin_delta = 0 / 0
```

Потом проверить процессы:

```text
run_agent_school
exact_count_cycle
codex_warehouse
codex.cmd
codex exec
absorb_atom_file
digest
```

Если найден активный процесс School/digest/producer:

```text
observe only
no duplicate launch
no cleanup
no shared-surface mutation
```

## 5. Active memory gate

Перед Live или absorption проверить наличие:

```text
.runtime/active_compact_semantic_memory_v1
.runtime/active_compact_semantic_memory_v1/manifest.json
.runtime/active_compact_semantic_memory_v1/index.json
.runtime/active_compact_semantic_memory_v1/cells.jsonl
```

Запрещено:

```text
удалять active memory
чистить .runtime во время School/digest
мутировать active memory без backup/hash/proof/authority
считать tail/sample доказательством всей memory
```

## 6. Где искать proof

Сначала смотреть:

```text
operations/school/proofs
operations/school/reports
operations/school/digestion
operations/school/memory
operations/gpt_handoff
reports/self_development
```

Но правило жёсткое:

```text
старый report не доказывает текущий live state
lab proof != live proof
Owner-reported live state != PROVEN_LIVE
```

## 7. Что делать при сбое

Не повторять ту же команду вслепую.

Сначала зафиксировать:

```text
какая команда
какой exit code
какой stderr/stdout
какой файл/report изменился
какой validator упал
что было запущено параллельно
```

Потом выбрать один ремонт:

```text
fix command parameters
fix validator/preflight gap
stop specific known launcher PID if hung and safe
write BLOCKED report
ask Owner for live authority if required
```

## 8. Что нельзя делать

```text
не запускать duplicate School
не broad-kill Codex / PowerShell / Python
не запускать Live без gate
не чистить .runtime во время активной School
не создавать новый launcher вместо run_agent_school.ps1
не создавать паспорт на каждый script
не патчить body-map только ради зелёного аудита
не говорить “готово / работает / live proven” без свежего proof
```

## 9. Минимальные готовые команды

### Проверка School policy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
```

### Маленький Test-run candidate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/run_agent_school.ps1 -Count 25 -Mode Test -Topics AUTO
```

### Live-run candidate, не выполнять без gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/run_agent_school.ps1 -Count <N> -Mode Live -Topics AUTO
```

## 10. Ответ GPT после любого действия School

GPT должен вернуть коротко:

```text
что хотел Owner
что было проверено
что было запущено или не запущено
какой validator/proof
какие файлы/reports появились
что proven
что not proven
следующий один шаг
```

## 11. Статус

```text
OWNER_SCHOOL_RUNBOOK = ACTIVE
SCHOOL_FOR_US = OPERATOR_CONTROL_ORGAN
SCHOOL_AS_AUTONOMOUS_AGENT_ORGAN = NOT_CLAIMED
ACTIVE_MEMORY = PROTECTED
LIVE_RUN = GATED
```
