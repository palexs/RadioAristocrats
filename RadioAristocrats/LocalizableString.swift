//
//  Strings.swift
//  RadioAristocrats
//
//  Created by Oleksandr Perepelitsyn on 3/2/16.
//  Copyright © 2016 RadioAristocrats. All rights reserved.
//

import Foundation

    public let kThursday = 5

public enum LocalizableString: String {
    case OnAir
    case UnknownTrack
    case UnknownArtist
    case NoTrackInfoErrorMessage
    case MusicQualityBest
    case Quality
    case Error
    case NoInternetConnection
    
    func localizedText(let isThursday: Bool) -> String {
        if (isThursday) { // Ukrainian
            switch self {
            case .OnAir:
                return "Прямий ефір"
            case .UnknownTrack:
                return "Невідомий трек"
            case .UnknownArtist:
                return "Невідомий виконавець"
            case .NoTrackInfoErrorMessage:
                return "Йой, щось пішло шкереберть!"
            case .MusicQualityBest:
                return "Найкраща"
            case .Quality:
                return "Якість"
            case .Error:
                return "Помилка"
            case .NoInternetConnection:
                return "Інтернет звя'зок відсутній!"
            }
        } else { // Russian
            switch self {
            case .OnAir:
                return "Прямой эфир"
            case .UnknownTrack:
                return "Неизвестный трек"
            case .UnknownArtist:
                return "Неизвестный исполнитель"
            case .NoTrackInfoErrorMessage:
                return "Упс, что-то пошло не так!"
            case .MusicQualityBest:
                return "Лучшее"
            case .Quality:
                return "Качество"
            case .Error:
                return "Ошибка"
            case .NoInternetConnection:
                return "Интернет связь отсутствует!"
            }
        }
    }
    
    static func isTodayThursday() -> Bool {
        let formatter  = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let myCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let myComponents = myCalendar.components(.Weekday, fromDate: NSDate()) // NSDate() returns today
        let weekDay = myComponents.weekday
        return weekDay == kThursday
    }
}
