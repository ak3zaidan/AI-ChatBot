import Foundation
import Alamofire

class ChatGPTAPI {
    private let endpointUrl = "https://api.openai.com/v1/chat/completions"
    private var currentStreamRequest: DataStreamRequest?
    
    func parseStreamData(_ data: String) ->[ChatStreamCompletionResponse] {
        let responseStrings = data.split(separator: "data:").map({$0.trimmingCharacters(in: .whitespacesAndNewlines)}).filter({!$0.isEmpty})
        let jsonDecoder = JSONDecoder()
        
        return responseStrings.compactMap { jsonString in
            guard let jsonData = jsonString.data(using: .utf8), let streamResponse = try? jsonDecoder.decode(ChatStreamCompletionResponse.self, from: jsonData) else {
                return nil
            }
            return streamResponse
        }
    }

    func sendStreamMessage(messages: [MessageAI]) -> DataStreamRequest {
        let openAIMessages = messages.map({OpenAIChatMessage(role: $0.role, content: $0.content)})
        let body = OpenAIChatBody(model: "gpt-3.5-turbo", messages: openAIMessages, stream: true)
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(Constants.openAIApiKey)"
        ]

        let streamRequest = AF.streamRequest(endpointUrl, method: .post, parameters: body, encoder: .json, headers: headers)
        currentStreamRequest = streamRequest
        return streamRequest
    }
    
    func cancelStream(){
        currentStreamRequest?.cancel()
        currentStreamRequest = nil
    }
}
