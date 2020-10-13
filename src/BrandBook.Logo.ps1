﻿function Format-DownloadSection($Images)
{
    $Images |
    ForEach-Object {
        "[$($_.Name)]($($_.DownloadPath))"
    } |
    Join-ToString -Delimeter ', '
}

function Format-Family
{
    process
    {
        $family = $_
        $previewLink = Split-Path -Leaf $family.Preview.RemotePath

"#### $($family.Title)"
''
        $($family.Description)
''
'|       |'
'| :---: |'
'|       |'
"| ![$($family.Title)]($previewLink) |"
"| Скачать: $(Format-DownloadSection($family.Images)) |"
''
    }
}

@"
# $($Model.Title)

$($Model.Description). Официальный сайт [$($Model.Site.Authority)]($($Model.Site)). Хэштег в социальных сетях _$($Model.HashTag)_.

## Логотип

Не стесняйтесь использовать наши логотипы при упоминании веб-сайта сообщества или любых его активностей.

### Форматы

- Используйте **PNG×200** только для предпросмотра или демонстрации.
- Используйте **PNG×800** как основной формат распостранения, например в социальных сетях.
- Используйте **EPS** для полиграфической продукции.
- Используйте **SVG** для получения логотипа любого другого необходимого формата или размера (без потери качества).

### Не нужно

- Изменять пропорции логотипов.
- Изменять цвета логотипов.
- Помещать текст или другие элементы поверх логотипов.
- Изменять шрифт или положение надписи на логотипах.
- Размещать на неконтрастном фоне прозрачную версию логотипа.
- Вставлять в логотип ссылку никак не связанную с сообществом.

### Варианты

Подбирайте вариант логотипа наиболее подходящий под ваши конкретные нужды.

"@
$Model.Logos | Format-Family
@"
## Шрифты

В нашем логотипе используется шрифт Consolas ™. Это шрифт по-умолчанию который используют .NET разработчики в своих редакторах кода.

См. также:

- [Consolas font family from Microsoft](https://docs.microsoft.com/en-us/typography/font-list/consolas)
- [Consolas from Wikipedia](https://en.wikipedia.org/wiki/Consolas)

## Цвета

Цветовая схема сообщества снована на цветах официального [логотипа .NET Foundation](https://github.com/dotnet/swag/tree/master/logo).

|             | [Пурпурный](https://www.color-hex.com/color/68217a) | [Фиолетовый](https://www.color-hex.com/color/cf18fd) | [Белый](https://www.color-hex.com/color/ffffff) |
| ----------- | --------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------- |
| **Web**     | #68217a                                             | #cf18fd                                              | #ffffff                                         |
| **RGB**     | 104,33,122                                          | (207,24,253)                                         | (255,255,255)                                   |
| **CMYK**    | 15,73,0,52                                          | 18,91,0,1                                            | 0,0,0,0                                         |
| **Pantone** | 259 C                                               | 246 C                                                | White                                           |

"@
