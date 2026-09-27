import SpriteKit

final class PetScene: SKScene {
    private let petNode = SKSpriteNode()
    private var animator: SpriteAnimator!
    private var lastPosture: PetPosture?
    private var lastFacing: Bool?
    private var lastTravelDown: Bool?

    var onPetClicked: (() -> Void)?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.isPaused = false
        view.preferredFramesPerSecond = 30

        animator = SpriteAnimator(sprite: petNode)
        petNode.position = CGPoint(x: size.width / 2, y: 0)
        addChild(petNode)
        animator.play(.walk, facingRight: false)
        lastPosture = .walkFloor
        lastFacing = false
    }

    override func didChangeSize(_ oldSize: CGSize) {
        petNode.position = CGPoint(x: size.width / 2, y: 0)
    }

    func apply(motion: PetMotionState, deltaTime: TimeInterval) {
        let set = SpriteAnimator.animationSet(for: motion.posture)
        let art = SpriteAnimator.artSelection(for: motion)

        if lastFacing != art.facingRight
            || lastPosture != motion.posture
            || lastTravelDown != art.travelDown
        {
            animator.play(set, facingRight: art.facingRight, travelDown: art.travelDown)
            lastFacing = art.facingRight
            lastPosture = motion.posture
            lastTravelDown = art.travelDown
        }

        animator.tick(deltaTime: deltaTime)
    }

    override func mouseDown(with event: NSEvent) {
        onPetClicked?()
    }
}
