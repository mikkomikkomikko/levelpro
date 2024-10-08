import SwiftUI

struct LaunchScreen: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    
    var body: some View {
        VStack {
            if isActive {
                ContentView() // Transition to your main view
            } else {
                ZStack {
                    Color.black // Background color
                        .ignoresSafeArea()

                    VStack {
                        Image("Splash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .foregroundColor(.white)
                        
                    }
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.5)) {
                            self.opacity = 1.0 // Fade in effect
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.isActive = true // Transition to main view after delay
                }
            }
        }
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}
