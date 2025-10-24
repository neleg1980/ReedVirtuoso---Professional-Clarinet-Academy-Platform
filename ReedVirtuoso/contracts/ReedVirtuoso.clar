;; ReedVirtuoso - Professional Clarinet Academy Platform
;; A blockchain-based platform for clarinet technique mastery, masterclass participation,
;; and virtuoso community recognition

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Token constants
(define-constant token-name "ReedVirtuoso Virtuosity Token")
(define-constant token-symbol "VVT")
(define-constant token-decimals u6)
(define-constant token-max-supply u38000000000) ;; 38k tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant reward-technique u2200000) ;; 2.2 VVT
(define-constant reward-masterclass u5800000) ;; 5.8 VVT
(define-constant reward-mastery u15000000) ;; 15.0 VVT

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var next-masterclass-id uint u1)
(define-data-var next-exercise-id uint u1)

;; Token balances
(define-map token-balances principal uint)

;; Virtuoso profiles
(define-map virtuoso-profiles
  principal
  {
    stage-name: (string-ascii 18),
    technique-level: (string-ascii 12), ;; "student", "amateur", "semi-pro", "professional"
    exercises-done: uint,
    masterclasses-held: uint,
    total-practice: uint,
    precision-score: uint, ;; 1-5
    enrollment-date: uint
  }
)

;; Clarinet masterclasses
(define-map clarinet-masterclasses
  uint
  {
    class-title: (string-ascii 12),
    repertoire: (string-ascii 8), ;; "baroque", "romantic", "modern", "jazz"
    difficulty: (string-ascii 8), ;; "basic", "intermediate", "advanced", "virtuoso"
    duration: uint, ;; minutes
    metronome-bpm: uint,
    max-students: uint,
    instructor: principal,
    exercise-count: uint,
    technique-rating: uint ;; average technique
  }
)

;; Technique exercises
(define-map technique-exercises
  uint
  {
    masterclass-id: uint,
    virtuoso: principal,
    exercise-type: (string-ascii 8),
    exercise-time: uint, ;; minutes
    metronome-speed: uint, ;; BPM
    fingering-accuracy: uint, ;; 1-5
    embouchure-control: uint, ;; 1-5
    dynamic-range: uint, ;; 1-5
    technique-notes: (string-ascii 12),
    exercise-date: uint,
    mastered: bool
  }
)

;; Masterclass reviews
(define-map masterclass-reviews
  { masterclass-id: uint, reviewer: principal }
  {
    rating: uint, ;; 1-10
    review-content: (string-ascii 12),
    instruction-quality: (string-ascii 5), ;; "poor", "fair", "good", "great", "superb"
    review-date: uint,
    endorsement-votes: uint
  }
)

;; Virtuoso masteries
(define-map virtuoso-masteries
  { virtuoso: principal, mastery: (string-ascii 12) }
  {
    mastery-date: uint,
    exercise-total: uint
  }
)

;; Helper function to get or create profile
(define-private (get-or-create-profile (virtuoso principal))
  (match (map-get? virtuoso-profiles virtuoso)
    profile profile
    {
      stage-name: "",
      technique-level: "student",
      exercises-done: u0,
      masterclasses-held: u0,
      total-practice: u0,
      precision-score: u1,
      enrollment-date: stacks-block-height
    }
  )
)

;; Token functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? token-balances user)))
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (asserts! (<= new-total-supply token-max-supply) err-invalid-input)
    (map-set token-balances recipient new-balance)
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

;; Create clarinet masterclass
(define-public (create-masterclass (class-title (string-ascii 12)) (repertoire (string-ascii 8)) (difficulty (string-ascii 8)) (duration uint) (metronome-bpm uint) (max-students uint))
  (let (
    (masterclass-id (var-get next-masterclass-id))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len class-title) u0) err-invalid-input)
    (asserts! (> duration u0) err-invalid-input)
    (asserts! (and (>= metronome-bpm u50) (<= metronome-bpm u180)) err-invalid-input)
    (asserts! (> max-students u0) err-invalid-input)
    
    (map-set clarinet-masterclasses masterclass-id {
      class-title: class-title,
      repertoire: repertoire,
      difficulty: difficulty,
      duration: duration,
      metronome-bpm: metronome-bpm,
      max-students: max-students,
      instructor: tx-sender,
      exercise-count: u0,
      technique-rating: u0
    })
    
    ;; Update profile
    (map-set virtuoso-profiles tx-sender
      (merge profile {masterclasses-held: (+ (get masterclasses-held profile) u1)})
    )
    
    ;; Award masterclass creation tokens
    (try! (mint-tokens tx-sender reward-masterclass))
    
    (var-set next-masterclass-id (+ masterclass-id u1))
    (print {action: "masterclass-created", masterclass-id: masterclass-id, instructor: tx-sender})
    (ok masterclass-id)
  )
)

;; Log technique exercise
(define-public (log-exercise (masterclass-id uint) (exercise-type (string-ascii 8)) (exercise-time uint) (metronome-speed uint) (fingering-accuracy uint) (embouchure-control uint) (dynamic-range uint) (technique-notes (string-ascii 12)) (mastered bool))
  (let (
    (exercise-id (var-get next-exercise-id))
    (masterclass (unwrap! (map-get? clarinet-masterclasses masterclass-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> exercise-time u0) err-invalid-input)
    (asserts! (and (>= metronome-speed u40) (<= metronome-speed u200)) err-invalid-input)
    (asserts! (and (>= fingering-accuracy u1) (<= fingering-accuracy u5)) err-invalid-input)
    (asserts! (and (>= embouchure-control u1) (<= embouchure-control u5)) err-invalid-input)
    (asserts! (and (>= dynamic-range u1) (<= dynamic-range u5)) err-invalid-input)
    
    (map-set technique-exercises exercise-id {
      masterclass-id: masterclass-id,
      virtuoso: tx-sender,
      exercise-type: exercise-type,
      exercise-time: exercise-time,
      metronome-speed: metronome-speed,
      fingering-accuracy: fingering-accuracy,
      embouchure-control: embouchure-control,
      dynamic-range: dynamic-range,
      technique-notes: technique-notes,
      exercise-date: stacks-block-height,
      mastered: mastered
    })
    
    ;; Update masterclass stats if mastered
    (if mastered
      (let (
        (new-exercise-count (+ (get exercise-count masterclass) u1))
        (current-technique (* (get technique-rating masterclass) (get exercise-count masterclass)))
        (technique-value (/ (+ fingering-accuracy embouchure-control dynamic-range) u3))
        (new-technique-rating (/ (+ current-technique technique-value) new-exercise-count))
      )
        (map-set clarinet-masterclasses masterclass-id
          (merge masterclass {
            exercise-count: new-exercise-count,
            technique-rating: new-technique-rating
          })
        )
        true
      )
      true
    )
    
    ;; Update profile
    (if mastered
      (begin
        (map-set virtuoso-profiles tx-sender
          (merge profile {
            exercises-done: (+ (get exercises-done profile) u1),
            total-practice: (+ (get total-practice profile) (/ exercise-time u60)),
            precision-score: (+ (get precision-score profile) (/ fingering-accuracy u12))
          })
        )
        (try! (mint-tokens tx-sender reward-technique))
        true
      )
      (begin
        (try! (mint-tokens tx-sender (/ reward-technique u5)))
        true
      )
    )
    
    (var-set next-exercise-id (+ exercise-id u1))
    (print {action: "exercise-logged", exercise-id: exercise-id, masterclass-id: masterclass-id})
    (ok exercise-id)
  )
)

;; Write masterclass review
(define-public (write-review (masterclass-id uint) (rating uint) (review-content (string-ascii 12)) (instruction-quality (string-ascii 5)))
  (let (
    (masterclass (unwrap! (map-get? clarinet-masterclasses masterclass-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (and (>= rating u1) (<= rating u10)) err-invalid-input)
    (asserts! (> (len review-content) u0) err-invalid-input)
    (asserts! (is-none (map-get? masterclass-reviews {masterclass-id: masterclass-id, reviewer: tx-sender})) err-already-exists)
    
    (map-set masterclass-reviews {masterclass-id: masterclass-id, reviewer: tx-sender} {
      rating: rating,
      review-content: review-content,
      instruction-quality: instruction-quality,
      review-date: stacks-block-height,
      endorsement-votes: u0
    })
    
    (print {action: "review-written", masterclass-id: masterclass-id, reviewer: tx-sender})
    (ok true)
  )
)

;; Endorse review
(define-public (endorse-review (masterclass-id uint) (reviewer principal))
  (let (
    (review (unwrap! (map-get? masterclass-reviews {masterclass-id: masterclass-id, reviewer: reviewer}) err-not-found))
  )
    (asserts! (not (is-eq tx-sender reviewer)) err-unauthorized)
    
    (map-set masterclass-reviews {masterclass-id: masterclass-id, reviewer: reviewer}
      (merge review {endorsement-votes: (+ (get endorsement-votes review) u1)})
    )
    
    (print {action: "review-endorsed", masterclass-id: masterclass-id, reviewer: reviewer})
    (ok true)
  )
)

;; Update technique level
(define-public (update-technique-level (new-technique-level (string-ascii 12)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-technique-level) u0) err-invalid-input)
    
    (map-set virtuoso-profiles tx-sender (merge profile {technique-level: new-technique-level}))
    
    (print {action: "technique-level-updated", virtuoso: tx-sender, level: new-technique-level})
    (ok true)
  )
)

;; Claim mastery
(define-public (claim-mastery (mastery (string-ascii 12)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (is-none (map-get? virtuoso-masteries {virtuoso: tx-sender, mastery: mastery})) err-already-exists)
    
    ;; Check mastery requirements
    (let (
      (mastery-achieved
        (if (is-eq mastery "scale-master") (>= (get exercises-done profile) u80)
        (if (is-eq mastery "etude-expert") (>= (get masterclasses-held profile) u12)
        false)))
    )
      (asserts! mastery-achieved err-unauthorized)
      
      ;; Record mastery
      (map-set virtuoso-masteries {virtuoso: tx-sender, mastery: mastery} {
        mastery-date: stacks-block-height,
        exercise-total: (get exercises-done profile)
      })
      
      ;; Award mastery tokens
      (try! (mint-tokens tx-sender reward-mastery))
      
      (print {action: "mastery-claimed", virtuoso: tx-sender, mastery: mastery})
      (ok true)
    )
  )
)

;; Update stage name
(define-public (update-stage-name (new-stage-name (string-ascii 18)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-stage-name) u0) err-invalid-input)
    (map-set virtuoso-profiles tx-sender (merge profile {stage-name: new-stage-name}))
    (print {action: "stage-name-updated", virtuoso: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-virtuoso-profile (virtuoso principal))
  (map-get? virtuoso-profiles virtuoso)
)

(define-read-only (get-clarinet-masterclass (masterclass-id uint))
  (map-get? clarinet-masterclasses masterclass-id)
)

(define-read-only (get-technique-exercise (exercise-id uint))
  (map-get? technique-exercises exercise-id)
)

(define-read-only (get-masterclass-review (masterclass-id uint) (reviewer principal))
  (map-get? masterclass-reviews {masterclass-id: masterclass-id, reviewer: reviewer})
)

(define-read-only (get-mastery (virtuoso principal) (mastery (string-ascii 12)))
  (map-get? virtuoso-masteries {virtuoso: virtuoso, mastery: mastery})
)