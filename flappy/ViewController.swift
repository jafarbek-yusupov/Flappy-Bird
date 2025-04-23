// Game configuration

import UIKit
    let initialGapHeight: CGFloat = 350
    let minimumGapHeight: CGFloat = 70
    let gapDecreaseRate: CGFloat = 5  // decrease gap per point scoredimport UIKit

    var difficultyLabel: UILabel!

class ViewController: UIViewController, UITextFieldDelegate {

    var bird: UIImageView!
    var birdVelocity: CGFloat = 0
    let gravity: CGFloat = 0.5
    
    var backgroundImageView: UIImageView!
    var scoreLabel: UILabel!
    var score: Int = 0
    var countdownLabel: UILabel!
    var countdownTimer: Timer?
    var countdownValue: Int = 3
    
    // Leaderboard components
    var leaderboardView: UIView!
    var nameTextField: UITextField!
    var submitButton: UIButton!
    var leaderboardTableView: UITableView!
    var leaderboardScores: [(name: String, score: Int)] = []

    var displayLink: CADisplayLink?
    var pipeTimer: Timer?
    var pipes: [UIImageView] = []
    var pipesPassedByBird = Set<UIImageView>()

    var isGameRunning = false

    // UI
    var startButton: UIButton!
    var gameOverLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadLeaderboard()
    }

    func setupUI() {
        
        let safeAreaInsets = view.safeAreaInsets
        
        // Background
        backgroundImageView = UIImageView(frame: view.bounds)
        backgroundImageView.image = UIImage(named: "background")
        backgroundImageView.contentMode = .scaleToFill
        view.addSubview(backgroundImageView)
        
        let playAreaFrame = CGRect(
                x: safeAreaInsets.left,
                y: safeAreaInsets.top,
                width: view.bounds.width - safeAreaInsets.left - safeAreaInsets.right,
                height: view.bounds.height - safeAreaInsets.top - safeAreaInsets.bottom
            )
        
        // Bird (hidden initially)
        bird = UIImageView(image: UIImage(named: "bird"))
        bird.frame = CGRect(x: 100, y: 300, width: 50, height: 50)
        bird.isHidden = true
        view.addSubview(bird)
        
        // Set up UI container for HUD elements to ensure they're on top
        let hudContainer = UIView(frame: view.bounds)
        hudContainer.backgroundColor = .clear
        view.addSubview(hudContainer)
        
        // Countdown Label - add to HUD container
        countdownLabel = UILabel()
        countdownLabel.text = "3"
        countdownLabel.textAlignment = .center
        countdownLabel.font = UIFont.boldSystemFont(ofSize: 100)
        countdownLabel.textColor = .white
        countdownLabel.frame = CGRect(x: 0, y: view.frame.height/2 - 100, width: view.frame.width, height: 200)
        countdownLabel.isHidden = true
        countdownLabel.layer.shadowColor = UIColor.black.cgColor
        countdownLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
        countdownLabel.layer.shadowOpacity = 0.8
        countdownLabel.layer.shadowRadius = 3
        hudContainer.addSubview(countdownLabel)
        
        // Difficulty indicator
        difficultyLabel = UILabel()
        difficultyLabel.text = "Gap: Easy"
        difficultyLabel.textAlignment = .center
        difficultyLabel.font = UIFont.boldSystemFont(ofSize: 18)
        difficultyLabel.textColor = .white
        difficultyLabel.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        difficultyLabel.layer.cornerRadius = 10
        difficultyLabel.layer.masksToBounds = true
        difficultyLabel.frame = CGRect(x: view.frame.width - 110, y: 75, width: 100, height: 30)
        difficultyLabel.isHidden = true
        difficultyLabel.layer.zPosition = 100
        hudContainer.addSubview(difficultyLabel)

        // Start button with effects - add to HUD container
        startButton = UIButton(type: .system)
        startButton.setTitle("Start Game", for: .normal)
        startButton.backgroundColor = UIColor(red: 0, green: 0.5, blue: 0.8, alpha: 0.8)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        startButton.layer.cornerRadius = 15
        startButton.frame = CGRect(x: view.frame.width/2 - 100, y: view.frame.height/2 - 30, width: 200, height: 60)
        
        // Add button effects
        startButton.showsTouchWhenHighlighted = true
        
        // Add custom hover and pressed states
        startButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        startButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        startButton.addTarget(self, action: #selector(startCountdown), for: .touchUpInside)
        
        hudContainer.addSubview(startButton)

        // Game Over label - add to HUD container
        gameOverLabel = UILabel()
        gameOverLabel.text = "Game Over!"
        gameOverLabel.textAlignment = .center
        gameOverLabel.font = UIFont.boldSystemFont(ofSize: 36)
        gameOverLabel.textColor = .red
        gameOverLabel.frame = CGRect(x: 0, y: view.frame.height/2 - 150, width: view.frame.width, height: 60)
        gameOverLabel.isHidden = true
        hudContainer.addSubview(gameOverLabel)

        // Score Label - add to HUD container
        scoreLabel = UILabel()
        scoreLabel.text = "Score: 0"
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 32)
        scoreLabel.textColor = .white
        scoreLabel.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5) // Semi-transparent background
        scoreLabel.layer.cornerRadius = 15
        scoreLabel.layer.masksToBounds = true
        scoreLabel.frame = CGRect(x: view.frame.width/2 - 75, y: 75, width: 150, height: 50)
        scoreLabel.isHidden = true
        scoreLabel.layer.zPosition = 200000 // Ensure it's on top
        hudContainer.addSubview(scoreLabel)
        
        // Setup Leaderboard
        setupLeaderboardUI()

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(flap))
        view.addGestureRecognizer(tapGesture)
    }
    
    func setupLeaderboardUI() {
        // Leaderboard container
        leaderboardView = UIView(frame: CGRect(x: view.frame.width/2 - 150, y: view.frame.height/2 - 200, width: 300, height: 400))
        leaderboardView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        leaderboardView.layer.cornerRadius = 20
        leaderboardView.isHidden = true
        leaderboardView.layer.zPosition = 101 // Higher than score
        view.addSubview(leaderboardView)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 20, width: 300, height: 30))
        titleLabel.text = "LEADERBOARD"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        leaderboardView.addSubview(titleLabel)
        
        // Your score
        let yourScoreLabel = UILabel(frame: CGRect(x: 20, y: 60, width: 260, height: 30))
        yourScoreLabel.text = "Your Score:"
        yourScoreLabel.textAlignment = .left
        yourScoreLabel.font = UIFont.systemFont(ofSize: 18)
        yourScoreLabel.textColor = .white
        leaderboardView.addSubview(yourScoreLabel)
        
        // Name input field
        nameTextField = UITextField(frame: CGRect(x: 20, y: 100, width: 260, height: 40))
        nameTextField.placeholder = "Enter your name"
        nameTextField.backgroundColor = .white
        nameTextField.textColor = .black
        nameTextField.layer.cornerRadius = 10
        nameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        nameTextField.leftViewMode = .always
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
        leaderboardView.addSubview(nameTextField)
        
        // Submit button
        submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit Score", for: .normal)
        submitButton.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0.3, alpha: 1)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        submitButton.layer.cornerRadius = 10
        submitButton.frame = CGRect(x: 20, y: 150, width: 260, height: 40)
        submitButton.addTarget(self, action: #selector(submitScore), for: .touchUpInside)
        leaderboardView.addSubview(submitButton)
        
        // Table view for scores
        leaderboardTableView = UITableView(frame: CGRect(x: 20, y: 200, width: 260, height: 150))
        leaderboardTableView.backgroundColor = .clear
        leaderboardTableView.register(UITableViewCell.self, forCellReuseIdentifier: "scoreCell")
        leaderboardTableView.dataSource = self
        leaderboardTableView.delegate = self
        leaderboardTableView.layer.cornerRadius = 10
        leaderboardView.addSubview(leaderboardTableView)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.8)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        closeButton.layer.cornerRadius = 10
        closeButton.frame = CGRect(x: 20, y: 360, width: 260, height: 30)
        closeButton.addTarget(self, action: #selector(closeLeaderboard), for: .touchUpInside)
        leaderboardView.addSubview(closeButton)
    }
    
    // MARK: - Game Control Methods
    
    @objc func startCountdown() {
        // Hide start button and show countdown
        startButton.isHidden = true
        countdownLabel.isHidden = false
        countdownValue = 3
        countdownLabel.text = "\(countdownValue)"
        
        // Place bird in starting position but don't start movement yet
        bird.isHidden = false
        bird.center = CGPoint(x: 100, y: 300)
        
        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }
    
    @objc func updateCountdown() {
        countdownValue -= 1
        
        // Animate countdown number
        UIView.animate(withDuration: 0.2, animations: {
            self.countdownLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.countdownLabel.transform = CGAffineTransform.identity
            }
        }
        
        if countdownValue > 0 {
            countdownLabel.text = "\(countdownValue)"
        } else {
            // Countdown finished, start the game
            countdownTimer?.invalidate()
            countdownLabel.isHidden = true
            startGame()
        }
    }
    
    @objc func startGame() {
        // Reset state
        isGameRunning = true
        birdVelocity = 0
        score = 0
        updateScoreLabel()
        
        pipes.forEach { $0.removeFromSuperview() }
        pipes.removeAll()
        pipesPassedByBird.removeAll()

        scoreLabel.isHidden = false
        difficultyLabel.isHidden = false
        difficultyLabel.text = "Gap: Easy"
        gameOverLabel.isHidden = true
        
        // Start game loop
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        displayLink?.add(to: .current, forMode: .default)

        pipeTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(spawnPipes), userInfo: nil, repeats: true)
    }
    
    @objc func gameLoop() {
        birdVelocity += gravity
        bird.center.y += birdVelocity

        // Check screen boundaries
        if bird.frame.minY <= 0 || bird.frame.maxY >= view.frame.height {
            gameOver()
            return
        }

        // Move pipes and check collisions
        for (index, pipe) in pipes.enumerated() {
            pipe.center.x -= 2

            // Check collision
            if bird.frame.intersects(pipe.frame) {
                gameOver()
                return
            }
            
            // Add score when passing pipe (only for top pipes to avoid double counting)
            if index % 2 == 0 && !pipesPassedByBird.contains(pipe) && pipe.center.x < bird.center.x {
                pipesPassedByBird.insert(pipe)
                score += 1
                updateScoreLabel()
                
                // Update difficulty display
                updateDifficultyDisplay()
            }
        }

        // Remove off-screen pipes
        pipes.removeAll(where: { pipe in
            if pipe.frame.maxX < 0 {
                pipesPassedByBird.remove(pipe)
                pipe.removeFromSuperview()
                return true
            }
            return false
        })
    }
    
    func updateDifficultyDisplay() {
        // Update the difficulty label based on current gap size
        let gapDecrease = min(CGFloat(score) * CGFloat(gapDecreaseRate), initialGapHeight - minimumGapHeight)
        let currentGapHeight = initialGapHeight - gapDecrease
        let percentDifficulty = (initialGapHeight - currentGapHeight) / (initialGapHeight - minimumGapHeight)
        
        // Update difficulty text
        switch percentDifficulty {
        case ..<0.3:
            difficultyLabel.text = "Gap: Easy"
            difficultyLabel.textColor = .green
        case 0.3..<0.6:
            difficultyLabel.text = "Gap: Medium"
            difficultyLabel.textColor = .yellow
        case 0.6..<0.9:
            difficultyLabel.text = "Gap: Hard"
            difficultyLabel.textColor = .orange
        default:
            difficultyLabel.text = "Gap: Extreme"
            difficultyLabel.textColor = .red
        }
        
        // If gap has reached minimum, flash the score briefly to indicate maximum difficulty
        if currentGapHeight <= minimumGapHeight {
            UIView.animate(withDuration: 1, animations: {
                self.scoreLabel.backgroundColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.7)
            }) { _ in
                UIView.animate(withDuration: 1) {
                    self.scoreLabel.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
                }
            }
        }
    }
    
    @objc func spawnPipes() {
        let pipeWidth: CGFloat = 60
        
        // Calculate current gap height based on score
        let gapDecrease = min(CGFloat(score) * CGFloat(gapDecreaseRate), initialGapHeight - minimumGapHeight)
        let currentGapHeight = initialGapHeight - gapDecrease
        
        let minHeight: CGFloat = 100
        let maxHeight = view.frame.height - currentGapHeight - 150
        let topHeight = CGFloat.random(in: minHeight...maxHeight)

        // Top pipe (flipped)
        let topPipe = UIImageView(frame: CGRect(x: view.frame.width, y: 0, width: pipeWidth, height: topHeight))
        topPipe.image = UIImage(named: "pipe")
        topPipe.contentMode = UIView.ContentMode.scaleToFill
        // Flip the image for top pipe
        topPipe.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        // Bottom pipe (normal orientation)
        let bottomY = topHeight + currentGapHeight
        let bottomPipe = UIImageView(frame: CGRect(x: view.frame.width, y: bottomY, width: pipeWidth, height: view.frame.height - bottomY))
        bottomPipe.image = UIImage(named: "pipe")
        bottomPipe.contentMode = UIView.ContentMode.scaleToFill

        view.addSubview(topPipe)
        view.addSubview(bottomPipe)

        pipes.append(topPipe)
        pipes.append(bottomPipe)
    }
    
    @objc func buttonTouchDown(_ sender: UIButton) {
        // Button pressed effect
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.backgroundColor = UIColor(red: 0, green: 0.4, blue: 0.7, alpha: 0.9) // Darker blue
        }
    }
    
    @objc func buttonTouchUp(_ sender: UIButton) {
        // Button released effect
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
            sender.backgroundColor = UIColor(red: 0, green: 0.5, blue: 0.8, alpha: 0.8) // Original blue
        }
    }
    
    @objc func gameOver() {
        isGameRunning = false
        displayLink?.invalidate()
        pipeTimer?.invalidate()
        gameOverLabel.isHidden = false
        
        // Show leaderboard instead of restart button
        leaderboardView.isHidden = false
        // Focus on name field
        nameTextField.becomeFirstResponder()
        
        // Update the score label in the leaderboard
        if let yourScoreLabel = leaderboardView.subviews.first(where: { ($0 as? UILabel)?.text?.hasPrefix("Your Score") == true }) as? UILabel {
            yourScoreLabel.text = "Your Score: \(score)"
        }
    }
    
    @objc func submitScore() {
        guard let name = nameTextField.text, !name.isEmpty else {
            // Alert for empty name
            let alert = UIAlertController(title: "Name Required", message: "Please enter your name to submit your score", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Add score to leaderboard
        leaderboardScores.append((name: name, score: score))
        
        // Sort by score (highest first)
        leaderboardScores.sort { $0.score > $1.score }
        
        // Limit to top 10
        if leaderboardScores.count > 10 {
            leaderboardScores = Array(leaderboardScores.prefix(10))
        }
        
        // Reload the table
        leaderboardTableView.reloadData()
        
        // Dismiss keyboard
        nameTextField.resignFirstResponder()
        
        // Save leaderboard
        saveLeaderboard()
    }
    
    @objc func closeLeaderboard() {
        leaderboardView.isHidden = true
        startButton.setTitle("Restart", for: .normal)
        startButton.isHidden = false
    }
    
    @objc func flap() {
        if isGameRunning {
            birdVelocity = -8
        }
    }
    
    func updateScoreLabel() {
        scoreLabel.text = "Score: \(score)"
    }
    
    func saveLeaderboard() {
        // Convert to dictionaries for storage
        let leaderboardData = leaderboardScores.map { ["name": $0.name, "score": $0.score] }
        UserDefaults.standard.set(leaderboardData, forKey: "leaderboard")
        UserDefaults.standard.synchronize()
    }
    
    func loadLeaderboard() {
        if let savedLeaderboard = UserDefaults.standard.object(forKey: "leaderboard") as? [[String: Any]] {
            leaderboardScores = savedLeaderboard.compactMap { dict in
                if let name = dict["name"] as? String,
                   let score = dict["score"] as? Int {
                    return (name: name, score: score)
                }
                return nil
            }
            leaderboardScores.sort { $0.score > $1.score }
        }
    }
    
    // MARK: - UITextField Delegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitScore()
        return true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return leaderboardScores.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scoreCell", for: indexPath)
        
        // Configure cell
        let entry = leaderboardScores[indexPath.row]
        cell.textLabel?.text = "\(indexPath.row + 1). \(entry.name): \(entry.score)"
        cell.textLabel?.textColor = .white
        cell.backgroundColor = UIColor(white: 0.2, alpha: 0.5)
        
        // Highlight current score
        if entry.score == score && nameTextField.text == entry.name {
            cell.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 0.7)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 30
    }
}
