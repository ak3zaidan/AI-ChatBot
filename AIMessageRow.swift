import SwiftUI
import Markdown
import Kingfisher

struct MessageRowView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    let message: MessageRow
    let retryCallback: (MessageRow) -> Void
    @EnvironmentObject var vm: ViewModel
    @EnvironmentObject var history: AIHistory
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top){
                if let image = auth.currentUser?.profileImageUrl {
                    KFImage(URL(string: image))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 25, height: 25)
                        .clipShape(Circle())
                } else {
                    ZStack(alignment: .center){
                        Image(systemName: "circle.fill")
                            .resizable()
                            .foregroundColor(colorScheme == .dark ? Color(UIColor.darkGray) : .black)
                            .frame(width: 25, height: 25)
                        Image(systemName: "questionmark")
                            .resizable()
                            .foregroundColor(.white)
                            .frame(width: 7, height: 12)
                    }
                }
                VStack {
                    HStack {
                        Text(auth.currentUser?.username ?? "you")
                            .font(.system(size: 14)).padding(.top, 5)
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                    HStack {
                        Text(message.send.text).font(.body).textSelection(.enabled)
                        Spacer()
                    }.padding(.top, 6)
                    if vm.hasImage.contains(message.send.text) || history.hasImageSec.contains(message.send.text){
                        HStack {
                            Text("Image added").font(.subheadline).foregroundStyle(.gray)
                            Spacer()
                        }.padding(.top, 4)
                    }
                }
            }
            if let response = message.response {
                HStack {
                    if vm.isInteracting {
                        LottieView(loopMode: .loop, name: "greenAnim").frame(width: 25, height: 25).scaleEffect(0.5)
                    } else {
                        Circle().foregroundStyle(.green).frame(width: 23, height: 23)
                    }
                    Text("AI")
                        .font(.system(size: 14)).foregroundStyle(.gray)
                    Spacer()
                }.padding(.top, 20)
                HStack {
                    messageRow(rowType: response, responseError: message.responseError)
                    Spacer()
                }.padding(.vertical, 6)
            }
        }
        .padding(.top, 17).padding(.leading, 3).padding(.bottom, 15)
    }
    
    func messageRow(rowType: MessageRowType, responseError: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 24) {
            messageRowContent(rowType: rowType, responseError: responseError)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    func messageRowContent(rowType: MessageRowType,responseError: String? = nil) -> some View {
        VStack(alignment: .leading) {
            switch rowType {
            case .attributed(let attributedOutput):
                attributedView(results: attributedOutput.results)
                
            case .rawText(let text):
                if !text.isEmpty {
                    Text(text)
                        .font(.body).padding(.leading, 32)
                        .multilineTextAlignment(.leading).textSelection(.enabled)
                }
            }
            
            if responseError != nil {
                HStack(spacing: 15){
                    Text("Error").foregroundStyle(.red).font(.system(size: 16))
                    Spacer()
                    Button {
                        if vm.isInteracting {
                            retryCallback(message)
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).foregroundStyle(.green).opacity(0.9)
                            HStack(spacing: 2){
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14))
                                Text("Regenerate").font(.system(size: 15))
                            }.foregroundStyle(.white)
                        }.frame(width: 120, height: 37)
                    }
                }.padding(.bottom).padding(.leading, 32).padding(.trailing)
            }
            
            if vm.isInteracting && vm.messages.last?.id == message.id {
                DotLoadingView().frame(width: 45, height: 22.5).padding(.leading, 32)
            }
        }
    }
    
    func attributedView(results: [ParserResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { parsed in
                if parsed.isCodeBlock {
                    CodeBlockView(parserResult: parsed)
                        .padding(.bottom, 24).padding(.horizontal, 8)
                } else {
                    Text(parsed.attributedString)
                        .font(.body).textSelection(.enabled).padding(.leading, 32)
                }
            }
        }
    }
}


struct DotLoadingView: View {
    @State private var showCircle1 = false
    @State private var showCircle2 = false
    @State private var showCircle3 = false
    
    var body: some View {
        HStack {
            Circle()
                .opacity(showCircle1 ? 1 : 0)
            Circle()
                .opacity(showCircle2 ? 1 : 0)
            Circle()
                .opacity(showCircle3 ? 1 : 0)
        }
        .foregroundColor(.gray.opacity(0.5))
        .onAppear { performAnimation() }
    }
    
    func performAnimation() {
        let animation = Animation.easeInOut(duration: 0.4)
        withAnimation(animation) {
            self.showCircle1 = true
            self.showCircle3 = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                self.showCircle2 = true
                self.showCircle1 = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(animation) {
                self.showCircle2 = false
                self.showCircle3 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.performAnimation()
        }
    }
}
