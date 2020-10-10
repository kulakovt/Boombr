$title = "Сообщество $($Model.Name)"
$position = "Независимое сообщество .NET разработчиков из города $($Model.City)"
if ($Model.Name -ieq 'DotNetRu')
{
     $title = $Model.Name
     $position = 'Объединение независимых русскоязычных .NET сообществ'
}
$logoPrefix = $Model.Name.ToLowerInvariant()
$logoSq = $Model.Logos | Where-Object { $_.Name -eq ($logoPrefix + '-logo-squared') } | Select-Single
$logoSqBr = $Model.Logos | Where-Object { $_.Name -eq ($logoPrefix + '-logo-squared-bordered') } | Select-Single
$logoSqWt = $Model.Logos | Where-Object { $_.Name -eq ($logoPrefix + '-logo-squared-white') } | Select-Single
$logoSqWtBr = $Model.Logos | Where-Object { $_.Name -eq ($logoPrefix + '-logo-squared-white-bordered') } | Select-Single

function Format-DownloadImage($Image)
{
    process
    {
        $image = $_
        $up1 = Split-Path -Parent $image.Path
        $link = 'https://raw.githubusercontent.com/AnatolyKulakov/SpbDotNet/master/Logo' |
            Join-Uri -RelativeUri (Split-Path -Leaf $up1) |
            Join-Uri -RelativeUri $image.Name

        $text = $image.Format.ToUpperInvariant()
        if ($image.Format -eq 'png')
        {
            $text += '×' + $image.Width
        }

        "[$text]($link)"
    }
}

function Format-DownloadSection($Images)
{
    $order = @(
        @{ Expression = { @('png', 'svg').IndexOf($_.Format) }; Descending = $true }
        @{ Expression = 'Width'; Ascending = $true }
    )

    $Images |
    Sort-Object $order |
    Format-DownloadImage |
    Join-ToString -Delimeter ', '
}

@"
# $title

$position. Официальный сайт [$($Model.Site.Authority)]($($Model.Site)). Хэштег в социальных сетях _$($Model.HashTag)_.

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

#### Квадрат

На светлом фоне используйте логотип без рамки. Подходит для создания круглых миниатюр в соц. сетях.

|       |
| :---: |
|       |
| ![Квадратный логотип $($Model.Name)]($($logoSq.Preview.Name)) |
| Скачать: $(Format-DownloadSection($logoSq.Images)) |

#### Квадрат с рамкой

На тёмном фоне используйте логотип с рамкой.

|       |
| :---: |
|       |
| ![Квадратный логотип $($Model.Name) с рамкой]($($logoSqBr.Preview.Name)) |
| Скачать: $(Format-DownloadSection($logoSqBr.Images)) |

#### Квадрат на прозрачном фоне

На тёмном цветном фоне используйте прозрачный логотип.

|       |
| :---: |
|       |
| ![Квадратный прозрачный логотип $($Model.Name)]($($logoSqWt.Preview.Name)) |
| Скачать: $(Format-DownloadSection($logoSqWt.Images)) |

#### Квадрат на прозрачном фоне с рамкой

На тёмном цветном фоне используйте прозрачный логотип с рамкой.

|       |
| :---: |
|       |
| ![Квадратный прозрачный логотип $($Model.Name) с рамкой]($($logoSqWtBr.Preview.Name))  |
| Скачать: $(Format-DownloadSection($logoSqWtBr.Images)) |

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
