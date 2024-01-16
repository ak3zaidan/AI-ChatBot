import Foundation
import SwiftUI
import UIKit
import CoreData

class AIHistory: ObservableObject {
    @Published var allMessages: [AllMessages] = []
    @Published var searchMessages: [iterateMessages] = []
    @Published var dateIndices = [datesQ]()
    @Published var hasImageSec = [String]()
    var store: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AIData")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    var context: NSManagedObjectContext {
        return self.store.viewContext
    }
    
    func sortTime() {
        DispatchQueue.main.async {
            self.searchMessages.sort { $0.date > $1.date }
        }
    }
    func sortSearch(text: String){
        DispatchQueue.main.async {
            self.searchMessages = self.searchMessages.sorted { (message1, message2) in
                let score1 = self.score(for: message1, searchString: text)
                let score2 = self.score(for: message2, searchString: text)
                return score1 > score2
            }
        }
    }
    func score(for message: iterateMessages, searchString: String) -> Int {
        let questionMatch = message.question.lowercased().contains(searchString.lowercased()) ? 2 : 0
        let answerMatch = message.answer.lowercased().contains(searchString.lowercased()) ? 1 : 0
        return questionMatch + answerMatch
    }
    
    @MainActor
    func getChats() async {
        let all = modelFetch()
        var new = [iterateMessages]()
        all.forEach { element in
            if let id = element.id, let text1 = element.text1, let text2 = element.text2, let date = element.date, !text2.isEmpty {
                new.append(iterateMessages(id: "\(UUID())", parentID: id, question: text1, answer: text2, date: date, hasImage: element.hasImage))
                if text1.isEmpty {
                    self.hasImageSec.append(text1)
                }
            }
        }
        new.sort { $0.date > $1.date }
        self.searchMessages = new
        self.getDates()
        Task {
            self.allMessages = await processElements(new: new)
        }
    }
    
    @MainActor
    func processElements(new: [iterateMessages]) async -> [AllMessages] {
        var newAll = [AllMessages]()

        for element in new {
            if let x = newAll.firstIndex(where: { $0.id == element.parentID }) {
                let parsingTask = ResponseParsingTask()
                let attributedSend = await parsingTask.parse(text: element.answer)
                let newMesRow = MessageRow(isInteracting: false, send: MessageRowType.rawText(element.question), response: .attributed(attributedSend))
                
                newAll[x].allM.insert(newMesRow, at: 0)
            } else {
                let parsingTask = ResponseParsingTask()
                let attributedSend = await parsingTask.parse(text: element.answer)
                let newMesRow = MessageRow(isInteracting: false, send: MessageRowType.rawText(element.question), response: .attributed(attributedSend))
                
                newAll.append(AllMessages(id: element.parentID, allM: [newMesRow]))
            }
        }
        return newAll
    }
    func saveChat(mess: [MessageRow], hasImage: [String]){
        var toAdd = [AIStorage]()
        let parent = "\(UUID())"
        DispatchQueue.main.async {
            mess.forEach { element in
                if let response = element.response?.text, !response.isEmpty {
                    if !self.searchMessages.contains(where: { $0.question == element.send.text && $0.answer == response }) {
                        let hasImage = hasImage.contains(element.send.text)
                        self.searchMessages.insert(iterateMessages(id: "\(UUID())", parentID: parent, question: element.send.text, answer: response, date: Date(), hasImage: hasImage), at: 0)
                        toAdd.append(AIStorage(id: parent, text1: element.send.text, text2: response, date: Date(), hasImage: hasImage))
                    }
                }
            }
            self.getDates()
            if !toAdd.isEmpty {
                self.ModelCreate(allAI: toAdd)
                self.allMessages.append(AllMessages(id: parent, allM: mess))
            }
        }
    }
    func deleteHistory(id: String, answer: String) {
        DispatchQueue.main.async {
            self.searchMessages.removeAll(where: { $0.id == id })
            self.getDates()
            self.modelDelete(answer: answer)
            for i in 0..<self.allMessages.count {
                for y in 0..<self.allMessages[i].allM.count {
                    if self.allMessages[i].allM[y].responseText == answer {
                        if self.allMessages[i].allM.count == 1 {
                            self.allMessages.remove(at: i)
                            return
                        } else {
                            self.allMessages[i].allM.remove(at: y)
                            return
                        }
                    }
                }
            }
        }
    }
    func modelDelete(answer: String) {
        let allAI = self.modelFetch()
        for ai in allAI {
            if ai.text2 == answer {
                context.delete(ai)
            }
        }
        do {
            try self.context.save()
        } catch {
            print("E")
        }
    }
    func ModelCreate(allAI: [AIStorage]) {
        for storage in allAI {
            let entity = AIData(context: context)
            entity.id = storage.id
            entity.text1 = storage.text1
            entity.text2 = storage.text2
            entity.date = storage.date
            entity.hasImage = storage.hasImage
        }

        do {
            try context.save()
        } catch {
            print("E")
        }
    }
    func modelFetch() -> [AIData] {
        var ai: [AIData] = []
        let fetchRequest: NSFetchRequest<AIData> = AIData.fetchRequest()

        do {
            ai = try self.context.fetch(fetchRequest)
        } catch {
            print("E")
        }
        return ai
    }
    func getDates(){
        DispatchQueue.main.async {
            self.dateIndices = []
        }
        var temp = [datesQ]()
        for i in 0..<self.searchMessages.count {
            if !searchMessages[i].answer.isEmpty && (!searchMessages[i].question.isEmpty || searchMessages[i].hasImage) {
                let days = howManyDaysOld(date: self.searchMessages[i].date)
                if days == 0 {
                    if !temp.contains(where: { $0.name == "Today" }) {
                        temp.append(datesQ(place: i, name: "Today"))
                    }
                } else if days == 1 {
                    if !temp.contains(where: { $0.name == "Yesterday" }) {
                        temp.append(datesQ(place: i, name: "Yesterday"))
                    }
                } else if days < 8 {
                    if !temp.contains(where: { $0.name == "Past Week" }) {
                        temp.append(datesQ(place: i, name: "Past Week"))
                    }
                } else if days <= 30 {
                    if !temp.contains(where: { $0.name == "Past Month" }) {
                        temp.append(datesQ(place: i, name: "Past Month"))
                    }
                } else {
                    if !temp.contains(where: { $0.name == "Past Year" }) {
                        temp.append(datesQ(place: i, name: "Past Year"))
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.dateIndices = temp
        }
    }
    func howManyDaysOld(date: Date) -> Int {
        let currentDate = Date()
        let calendar = Calendar.current
        if let daysDifference = calendar.dateComponents([.day], from: date, to: currentDate).day {
            return daysDifference
        } else {
            return 0
        }
    }
}

class ViewModel: ObservableObject {
    @Published var isInteracting = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
    @Published var hasImage = [String]()
    let service = ChatGPTAPI()
    
    @MainActor
    func sendTapped(main: String, newText: String?, text2: String) async {
        if let str = newText {
            await AskQuestion(text: str, text2: text2)
        } else {
            await AskQuestion(text: main, text2: text2)
        }
    }
    
    @MainActor
    func retry(message: MessageRow) async {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        self.messages.remove(at: index)
        await AskQuestion(text: message.sendText, text2: "")
    }
    
    func cancelStreamingResponse() {
        if !messages.isEmpty {
            let x = messages.count - 1
            self.messages[x].isInteracting = false
            self.messages[x].responseError = "Cancelled"
        }
        self.isInteracting = false
        service.cancelStream()
    }
    
    @MainActor
    private func AskQuestion(text: String, text2: String) async {
        isInteracting = true
        var streamText = ""
        var messageRow = MessageRow(isInteracting: true, send: .rawText(text), response: .rawText(streamText), responseError: nil)
        
        
        let parsingTask = ResponseParsingTask()
        let attributedSend = await parsingTask.parse(text: text)
        messageRow.send = .attributed(attributedSend)
        
        self.messages.append(messageRow)
        
        let parserThresholdTextCount = 64
        var currentTextCount = 0
        var currentOutput: AttributedOutput?
        
        var finalSend = text
        if !text2.isEmpty {
            self.hasImage.append(finalSend)
            finalSend += " The image has already been scanned for text, this is the scanned text: \(text2)"
        }
        
        let messages = [MessageAI(id: UUID().uuidString, role: .user, content: finalSend, createAt: Date())]
        service.sendStreamMessage(messages: messages).responseStreamString { [weak self] stream in
            guard let self = self else { return }
            switch stream.event {
            case .stream(let response):
                switch response {
                case .success(let string):
                    let streamResponse = self.service.parseStreamData(string)
                    
                    streamResponse.forEach { newMessageResponse in
                        guard let text = newMessageResponse.choices.first?.delta.content else {
                            return
                        }
                        streamText += text
                        currentTextCount += text.count
                        
                        Task {
                            if currentTextCount >= parserThresholdTextCount || text.contains("```") {
                                currentOutput = await parsingTask.parse(text: streamText)
                                currentTextCount = 0
                            }
                            
                            if let currentOutput = currentOutput, !currentOutput.results.isEmpty {
                                let suffixText = streamText.trimmingPrefix(currentOutput.string)
                                var results = currentOutput.results
                                let lastResult = results[results.count - 1]
                                var lastAttrString = lastResult.attributedString
                                if lastResult.isCodeBlock {
                                    lastAttrString.append(AttributedString(String(suffixText), attributes: .init([.font: UIFont.systemFont(ofSize: 12).apply(newTraits: .traitMonoSpace), .foregroundColor: UIColor.white])))
                                } else {
                                    lastAttrString.append(AttributedString(String(suffixText)))
                                }
                                results[results.count - 1] = ParserResult(attributedString: lastAttrString, isCodeBlock: lastResult.isCodeBlock, codeBlockLanguage: lastResult.codeBlockLanguage)
                                messageRow.response = .attributed(.init(string: streamText, results: results))
                            } else {
                                messageRow.response = .attributed(.init(string: streamText, results: [
                                    ParserResult(attributedString: AttributedString(stringLiteral: streamText), isCodeBlock: false, codeBlockLanguage: nil)
                                ]))
                            }
                            
                            self.messages[self.messages.count - 1] = messageRow
                            if let currentString = currentOutput?.string, currentString != streamText {
                                let output = await parsingTask.parse(text: streamText)
                                messageRow.response = .attributed(output)
                            }
                        }
                    }
                case .failure(_):
                    DispatchQueue.main.async {
                        if !self.messages.isEmpty {
                            for i in 0..<self.messages.count {
                                self.messages[i].isInteracting = false
                            }
                        }
                        self.isInteracting = false
                    }
                }
            case .complete(_):
                DispatchQueue.main.async {
                    if !self.messages.isEmpty {
                        for i in 0..<self.messages.count {
                            self.messages[i].isInteracting = false
                        }
                    }
                    self.isInteracting = false
                }
            }
        }
    }
}
