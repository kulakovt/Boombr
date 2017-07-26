# Boombr

[![Build status](https://ci.appveyor.com/api/projects/status/pynxm1tg9khxpqoc?svg=true)](https://ci.appveyor.com/project/AnatolyKulakov/boombr)

Boombr — скрипт для помощи в подготовке статического содержимого для сообществ [DotNetRu](http://dotnet.ru/).

## Настройка рабочего окружения

Для работы Boombr требует [PowerShell 5](https://www.microsoft.com/en-us/download/details.aspx?id=50395).

1. Склонируйре репозиторий Boombr

```batch
git clone https://github.com/AnatolyKulakov/Boombr.git
```

2. Склонируйте репозиторий с Audit'ом, если будите с ним работать

```bash
git clone https://github.com/DotNetRu/Audit.git
```

3. Склонируйте репозиторий с Wiki, если будите с ней работать

```posh
git clone https://github.com/AnatolyKulakov/SpbDotNet.wiki.git
```

Все репозитории должны лежать рядом, в одной общей папке.

## Возможности

Перед началом работ убедитесь что все используемые репозитории обновлены.

### Создание новой встречи

Для создания новой встречи запустите команду:

```posh
./Invoke-Boombr.ps1 new meetup
```

Откроется форма с заполненным примером одной встречи, места, друзьями, докладчиками и докладами. Заполните поля актуальной информацией, удалите не нужные данные, сохраните изменения и закройте форму. После этого Boombr добавить в репозиторий Audit'а все введённые данные.

Boombr пока не умеет работать с картинками. Поэтому для кажной встречи необходимо отдельно добавить в Audit:

- логотипы друзей
- фотографии спикеров

### Актуализация Wiki

Для перегенерации Wiki запустите команду:

```posh
./Invoke-Boombr.ps1 build wiki
```

Boombr перестроит все страницы для всех сообществ из текущей версии Audit'а.
