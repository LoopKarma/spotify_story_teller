import Foundation
import OpenAI

class OpenAIManager {
    private let openAI: OpenAI
    
    init(apiKey: String) {
        self.openAI = OpenAI(apiToken: Environment.shared.openAIApiKey)
    }
    
    func generateTrackInsights(track: String, artist: String, album: String) async throws -> String {
        print(track, artist, album)
        let prompt = """
        Возьми информацию об этом музыкальном треке \(track) - \(artist) || с альбома: \(album)

        Ты ищешь информацию такой структуры: 

        О чем эта песня или альбом? Приведи цитаты текса для полноты описания сюжета или задавания контекста. 

        Пронализируй музыкальную часть песни, какие-то особенности если они есть. 

        Удели внимание обложке альбома. 

        Есть ли история связанная с написанием или выпуском песни или альбома?

        Есть ли видимое влияние этой песни или альбома? 


        Приведи дополнительно основную метадату этого трека в конце в виде таблицы. 
        В конце выведи 3 связанные песни или альбома. 
        """
        
        // Create the message parameters directly as non-optional values
        let systemMessage = ChatQuery.ChatCompletionMessageParam(
            role: .system,
            content: "You are a knowledgeable music expert who provides interesting insights about songs."
        )
        
        let userMessage = ChatQuery.ChatCompletionMessageParam(
            role: .user,
            content: prompt
        )
        
        // Use the proper model string instead of enum
        let query = ChatQuery(
            messages: [systemMessage!, userMessage!],
            model: .gpt4_o,
            maxTokens: 5000
        )
        
        let result = try await openAI.chats(query: query)
        
        if let choice = result.choices.first, let content = choice.message.content {
            return content
        } else {
            return "Couldn't generate insights for this track."
        }
    }
}
