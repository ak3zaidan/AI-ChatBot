import SwiftUI

struct AskAIView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var history: AIHistory
    @EnvironmentObject var vm: ViewModel
    @State var atTop = true
    @State var showDownButton = true
    @State var isTop = false
    @Binding var showMenu: Bool
    @State var isCollapsed = false
    @State var asktext = ""
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @Binding var should_Scroll_Interacting: Bool
    @State var scrollViewSize: CGSize = .zero
    @State var wholeSize: CGSize = .zero
    let rando: [randomQ] = [randomQ(one: "Basic python script", two: "to multiply three numbers"), randomQ(one: "Help me pick", two: "a birthday gift for my mom"), randomQ(one: "Explain this code:", two: "rm -rf `ls -t ${FOLDER}/other_folder | awk 'NR>5'`"), randomQ(one: "How many letters", two: "are in the Arabic alphabet"), randomQ(one: "Make a list", two: "of the healthiest meals")]
    
    var body: some View {
        VStack(spacing: 0){
            HStack {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation {
                        showMenu.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4){
                        Rectangle().frame(width: 28, height: 5)
                        Rectangle().frame(width: 20, height: 4)
                    }.foregroundStyle(colorScheme == .dark ? .white : .black)
                }.offset(y: 2)
                Button {
                    if !vm.messages.isEmpty {
                        history.saveChat(mess: vm.messages, hasImage: vm.hasImage)
                    }
                    vm.messages = []
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 25))
                        .foregroundStyle(.gray)
                }.padding(.leading, 25).disabled(vm.isInteracting)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 25))
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }.padding(.horizontal)
            VStack {
                ScrollViewReader { proxy in
                    ZStack {
                        Color.gray.opacity(0.0001)
                        if vm.messages.isEmpty {
                            VStack {
                                Spacer()
                                AskIcon(isTop: $isTop)
                                Spacer()
                            }
                        } else {
                            ChildSizeReader(size: $wholeSize) {
                                ScrollView {
                                    ChildSizeReader(size: $scrollViewSize) {
                                        LazyVStack(spacing: 0) {
                                            Color.clear.frame(height: 1).id("scrollDown")
                                            ForEach(vm.messages.reversed()) { message in
                                                MessageRowView(message: message) { message in
                                                    Task { @MainActor in
                                                        await vm.retry(message: message)
                                                    }
                                                }
                                                .rotationEffect(.degrees(180.0))
                                                .scaleEffect(x: -1, y: 1, anchor: .center)
                                            }
                                        }
                                        .background(GeometryReader {
                                            Color.clear.preference(key: ViewOffsetKey.self,
                                                                   value: -$0.frame(in: .named("scroll")).origin.y)
                                        })
                                        .onPreferenceChange(ViewOffsetKey.self) { value in
                                            let full = scrollViewSize.height - wholeSize.height
                                            if full > value + 100 {
                                                withAnimation { atTop = false }
                                            } else {
                                                withAnimation { atTop = true }
                                            }
                                        }
                                    }
                                }
                                .rotationEffect(.degrees(180.0))
                                .scaleEffect(x: -1, y: 1, anchor: .center)
                            }
                        }
                        if !atTop && !vm.messages.isEmpty && showDownButton {
                            VStack {
                                Spacer()
                                Button {
                                    showDownButton = false
                                    atTop = true
                                    withAnimation {
                                        proxy.scrollTo("scrollDown", anchor: .bottom)
                                    }
                                    if vm.isInteracting {
                                        should_Scroll_Interacting = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showDownButton = true
                                    }
                                } label: {
                                    ZStack {
                                        Circle().foregroundStyle(.indigo)
                                        Image(systemName: "chevron.down")
                                            .font(.title3).foregroundStyle(.white).offset(y: 1)
                                    }.frame(width: 35, height: 35)
                                }
                            }.transition(.move(edge: .bottom)).padding(.bottom, 20)
                        }
                    }
                    .onChange(of: vm.messages.last?.responseText) { _ in
                        if should_Scroll_Interacting {
                            withAnimation {
                                proxy.scrollTo("scrollDown", anchor: .bottomTrailing)
                            }
                        }
                    }
                }
            }.padding(.vertical, 8).blur(radius: isCollapsed ? 5 : 0)
            if vm.messages.isEmpty && vm.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                randomOptions().padding(.bottom).blur(radius: isCollapsed ? 5 : 0)
            }
            AITextField()
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .background && !vm.messages.isEmpty {
                history.saveChat(mess: vm.messages, hasImage: vm.hasImage)
            }
        }
        .onAppear {
            isTop = true
            Task {
                if history.allMessages.isEmpty {
                    await history.getChats()
                }
            }
        }
        .onDisappear {
            isTop = false
            if !vm.messages.isEmpty {
                history.saveChat(mess: vm.messages, hasImage: vm.hasImage)
            }
        }
        .overlay {
            LiquidAIMenuButtons(isCollapsed: $isCollapsed)
        }
    }
    func AITextField() -> some View {
        ZStack(alignment: .bottomTrailing){
            HStack {
                Spacer()
                CustomAIField(placeholder: Text("Message"), text: $vm.inputMessage)
                    .frame(width: widthOrHeight(width: true) * 0.83)
            }
            Button {
                if vm.isInteracting {
                    vm.cancelStreamingResponse()
                } else {
                    let toSend = vm.inputMessage
                    vm.inputMessage = ""
                    Task { @MainActor in
                        await vm.sendTapped(main: toSend, newText: nil, text2: "")
                    }
                }
            } label: {
                if vm.isInteracting {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                        .padding(6)
                        .foregroundStyle(.white)
                        .background(.red)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                        .padding(6)
                        .foregroundStyle(.white)
                        .background(.blue)
                        .clipShape(Circle())
                        .opacity(vm.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
            }
            .disabled(!vm.isInteracting && vm.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, 5).padding(.bottom, 5)
        }.padding(.bottom, 6).padding(.trailing, 12)
    }
    func randomOptions() -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 10, height: 10)
                ForEach(rando, id: \.self) { element in
                    Button {
                        let toSend = vm.inputMessage
                        vm.inputMessage = ""
                        Task { @MainActor in
                            await vm.sendTapped(main: toSend, newText: element.one + " " + element.two, text2: "")
                        }
                    } label: {
                        VStack(spacing: 6){
                            HStack {
                                Text(element.one).bold()
                                Spacer()
                            }.padding(.leading, 7)
                            HStack {
                                Text(element.two)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .font(.system(size: 14)).foregroundStyle(.gray)
                                Spacer()
                            }.padding(.leading, 7)
                        }
                        .frame(height: 65)
                        .padding(.horizontal, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(15, corners: .allCorners)
                    }
                }
                Color.clear.frame(width: 10, height: 10)
            }
        }.scrollIndicators(.hidden)
    }
}

struct CustomAIField: View {
    var placeholder: Text
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    
    var body: some View{
        ZStack(alignment: .leading){
            if text.isEmpty {
                placeholder
                    .opacity(0.5)
                    .offset(x: 8)
                    .foregroundColor(.gray)
                    .font(.system(size: 17))
            }
            TextField("", text: $text, axis: .vertical)
                .tint(.blue)
                .lineLimit(5)
                .padding(.vertical, 3)
                .padding(.leading, 8)
                .padding(.trailing, 40)
                .frame(minHeight: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: 14).stroke(.gray, lineWidth: 1)
                }
            
        }
    }
}

struct LiquidAIMenuButtons: View {
    @State var offsetOne: CGSize = .zero
    @State var offsetTwo: CGSize = .zero
    @Binding var isCollapsed: Bool
    @State private var trueSize: Bool = false
    @State private var showCamera: Bool = false
    @State private var selectedImage: UIImage?
    @State var showImagePicked: Bool = false
    @State var showPicker: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            if isCollapsed {
                Color.gray.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.4)){
                            trueSize.toggle()
                        }
                        withAnimation { isCollapsed.toggle() }
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.1).speed(0.5)) {
                            offsetOne  = isCollapsed ? CGSize(width: 0, height: -75) : .zero
                            offsetTwo  = isCollapsed ? CGSize(width: 0, height: -145) : .zero
                        }
                    }
            }
            VStack {
                Spacer()
                HStack {
                    Rectangle()
                        .fill(.linearGradient(colors: [.gray.opacity(0.5), .gray], startPoint: .bottom, endPoint: .top))
                        .mask(canvas)
                        .overlay {
                            ZStack {
                                CancelButton().blendMode(.softLight).rotationEffect(Angle(degrees: isCollapsed ? 90 : 45))
                                CameraButton().offset(offsetOne).blendMode(.softLight).opacity(isCollapsed ? 1 : 0)
                                PhotosButton().offset(offsetTwo).blendMode(.softLight).opacity(isCollapsed ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .offset(x: 9.5, y: -4)
                        }
                        .frame(width: 65, height: isCollapsed ? 250 : 65)
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera, content: {
            SnapCameraHelper()
        })
        .fullScreenCover(isPresented: $showImagePicked, content: {
            SnapCamera(image: nil, image2: $selectedImage)
                .onDisappear {
                    selectedImage = nil
                }
        })
        .sheet(isPresented: $showPicker, onDismiss: loadImage){
            ImagePicker(selectedImage: $selectedImage)
                .tint(colorScheme == .dark ? .white : .black)
        }
    }
    var canvas: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.9, color: .black))
            context.addFilter(.blur(radius: 5))

            context.drawLayer { ctx in
                for index in [1,2,3,4,5] {
                    if let resolvedView = context.resolveSymbol(id: index) {
                        ctx.draw(resolvedView, at: CGPoint(x: 32, y: size.height - 27))
                    }
                }
            }
        } symbols: {
            Symbol(diameter: 40).tag(1)

            Symbol(offset: offsetOne, diameter: 60).tag(2).opacity(trueSize ? 1 : 0)
            
            Symbol(offset: offsetTwo, diameter: 60).tag(3).opacity(trueSize ? 1 : 0)
        }
    }
}

extension LiquidAIMenuButtons {
    func loadImage() {
        if selectedImage != nil {
            showImagePicked = true
        }
    }
    private func Symbol(offset: CGSize = .zero, diameter: CGFloat) -> some View {
        Circle().frame(width: diameter, height: diameter).offset(offset)
    }
    func closeView(){
        if !isCollapsed {
            withAnimation(.easeIn(duration: 0.05)){
                trueSize.toggle()
            }
        } else {
            withAnimation(.easeIn(duration: 0.4)){
                trueSize.toggle()
            }
        }
        withAnimation { isCollapsed.toggle() }
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.1).speed(0.5)) {
            offsetOne  = isCollapsed ? CGSize(width: 0, height: -75) : .zero
            offsetTwo  = isCollapsed ? CGSize(width: 0, height: -145) : .zero
        }
    }
    func CancelButton() -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            closeView()
        } label: {
            ZStack {
                Rectangle().frame(width: 45, height: 45).foregroundStyle(.gray).opacity(0.001)
                Image(systemName: "xmark")
                    .resizable()
                    .foregroundStyle(.white)
                    .frame(width: 12, height: 12)
                    .aspectRatio(.zero, contentMode: .fit).contentShape(Circle())
            }
        }
    }
    func CameraButton() -> some View {
        Button {
            showCamera = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            closeView()
        } label: {
            ZStack {
                Image(systemName: "camera.fill").scaleEffect(1.2).foregroundStyle(.white)
            }
        }.frame(width: 45, height: 45)
    }
    func PhotosButton() -> some View {
        Button {
            showPicker = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            closeView()
        } label: {
            ZStack {
                Image(systemName: "photo").scaleEffect(1.3).foregroundStyle(.white)
            }
        }.frame(width: 45, height: 45)
    }
}
