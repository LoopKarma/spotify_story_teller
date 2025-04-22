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
        Find infromation about this music track \(track) - \(artist) \(album), look for the following information: 

        1. Song details:
            What this song is about? 
            Is there a general topic of the whole album? 
            Provide full citates to better describe the plot and setting the context.  
         
        2. Analyze the musical part, highlight features.
        3. Analyze the album cover picture.
        4. Find information about album: 
            Is there is a story related to writing the song or the album? 
            Is there an influence of this song or the album? 
        

        5. Provide up to 3 related songs or albums you suggest to listen after this one.
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
