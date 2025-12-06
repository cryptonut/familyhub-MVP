# Enhanced Project Setup Prompt for Cursor Agent

## Context & Role
You are an expert full-stack developer agent specializing in blockchain applications, React Native, and Firebase infrastructure. Your task is to build the **"Open Integrity" MVP**—a blockchain-based direct democracy platform for Australian political parties.

**Source Documents**: Use the Business Requirements Document (BRD), Functional Requirements Document (FRD), and Technical Specifications Document (TSD) as your authoritative blueprint. These should be provided as context or stored in `docs/`.

**Repository**: Private repo at `https://github.com/cryptonut/open-integrity.git` (you have access—clone if needed).

---

## Technology Stack

### Core Technologies
- **Blockchain**: Solana (Rust for smart contracts)
- **Frontend**: React Native (cross-platform: web, iOS, Android)
- **Backend**: Firebase ecosystem
  - Firestore (NoSQL database)
  - Cloud Functions (serverless logic)
  - Storage (file attachments)
  - Authentication (custom Solana wallet integration)
- **Visualization**: D3.js (dashboards and analytics)
- **External APIs**: myGovID API (mock for development)

### Development Tools
- **Package Managers**: npm/yarn for Node.js, Cargo for Rust
- **Testing**: Jest (frontend), Cargo test (contracts), Firebase emulators
- **Linting/Formatting**: ESLint, Prettier, rustfmt
- **Version Control**: Git with conventional commits

---

## Execution Strategy

### Principles
1. **Sequential Phases**: Execute phases 0-6 in order. Do not skip ahead.
2. **Test Before Commit**: Each phase must include working tests before committing.
3. **Explicit Pauses**: After each phase, pause and request user input for external dependencies (API keys, credentials, configs). **Never assume or fake credentials.**
4. **Incremental Commits**: Commit after each phase with descriptive messages following conventional commits format.
5. **Error Handling**: If any step fails, document the error, suggest fixes, and pause for user guidance.
6. **Documentation**: Update README and relevant docs as you build.

### Commit Message Format
```
Phase N: [Brief description]

- [Feature 1]
- [Feature 2]
- [Testing notes]
- [Known issues/blockers]
```

---

## Phase 0: Repository Initialization & Foundation

### Objectives
- Establish repository structure
- Configure development environment
- Set up tooling and standards

### Tasks

#### 1. Repository Setup
- [ ] Clone or initialize the repository
- [ ] Verify access and permissions
- [ ] Create initial branch structure (main, develop)

#### 2. Project Structure
Create the following directory structure:
```
open-integrity/
├── contracts/          # Solana smart contracts (Rust)
│   ├── sparks-token/
│   ├── idea-vault/
│   ├── voting-escrow/
│   ├── revival-logic/
│   └── reward-distributor/
├── frontend/           # React Native application
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── services/
│   │   ├── hooks/
│   │   ├── utils/
│   │   └── types/
│   ├── __tests__/
│   └── package.json
├── backend/            # Firebase functions and config
│   ├── functions/
│   ├── firestore.rules
│   ├── storage.rules
│   └── firebase.json
├── docs/               # Documentation
│   ├── BRD.md
│   ├── FRD.md
│   ├── TSD.md
│   └── API.md
├── scripts/            # Utility scripts
├── .github/            # CI/CD workflows
│   └── workflows/
└── tests/              # Integration tests
```

#### 3. Configuration Files

**`.gitignore`** (comprehensive):
```gitignore
# Dependencies
node_modules/
target/
Cargo.lock

# Environment & Secrets
.env
.env.local
*.key
*.pem
*.p12
firebase-debug.log
firestore-debug.log
ui-debug.log

# Build artifacts
dist/
build/
*.log
.DS_Store

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
Thumbs.db
.DS_Store

# Firebase
.firebase/
.firebaserc.local

# Solana
test-ledger/
```

**`.env.example`**:
```env
# Solana Configuration
SOLANA_RPC_URL=https://api.devnet.solana.com
SOLANA_NETWORK=devnet
SOLANA_KEYPAIR_PATH=~/.config/solana/id.json

# Firebase Configuration
FIREBASE_PROJECT_ID=open-integrity-dev
FIREBASE_API_KEY=your_api_key_here
FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your_project.appspot.com

# External APIs
MYGOVID_API_KEY=your_mygovid_key_here
MYGOVID_API_URL=https://api.mygovid.gov.au/v1

# App Configuration
APP_ENV=development
APP_VERSION=0.1.0
```

**`LICENSE`** (MIT):
- Standard MIT License text with current year and project name

**`README.md`** (comprehensive):
- Executive Summary from BRD
- Architecture overview diagram (ASCII or link)
- Prerequisites (Node.js 18+, Rust 1.70+, Solana CLI, Firebase CLI)
- Quick start instructions
- Development workflow
- Testing guide
- Deployment guide
- Contributing guidelines
- Links to documentation

**`CONTRIBUTING.md`**:
- Code style guidelines (Prettier config, ESLint rules)
- Git workflow (feature branches, PR process)
- Testing requirements
- Documentation standards
- Issue/PR templates

#### 4. Development Tooling

**`package.json`** (root):
- Scripts for: install, test, lint, format, build
- Workspace configuration if using monorepo

**`.prettierrc`**:
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2
}
```

**`.eslintrc.js`**:
- React Native specific rules
- TypeScript support
- Import ordering

**`rustfmt.toml`** (for contracts):
- Standard Rust formatting rules

#### 5. CI/CD Setup
- [ ] Create `.github/workflows/ci.yml`:
  - Run tests on PR
  - Lint checks
  - Build verification
  - Security scanning (optional)

#### 6. Documentation
- [ ] Copy BRD, FRD, TSD to `docs/` as Markdown
- [ ] Create `docs/API.md` template for API documentation
- [ ] Create `docs/ARCHITECTURE.md` for system design

### Testing
- [ ] Verify `.gitignore` works correctly
- [ ] Test that all config files are valid
- [ ] Confirm directory structure is created

### Commit
```
Phase 0: Repository initialization and foundation

- Created project structure with contracts/, frontend/, backend/, docs/
- Added comprehensive .gitignore for Node.js, Rust, Firebase, Solana
- Configured development tooling (Prettier, ESLint, rustfmt)
- Added .env.example with all required environment variables
- Set up CI/CD workflow skeleton
- Added MIT LICENSE and CONTRIBUTING.md
- Created comprehensive README.md with setup instructions
```

### Pause & Request
**Before proceeding to Phase 1, request:**
- [ ] GitHub repository access confirmation
- [ ] Any required GitHub secrets for CI/CD (if applicable)
- [ ] Preferred branch protection rules (if any)

---

## Phase 1: Solana Contracts + Firebase Infrastructure

### Objectives
- Implement core Solana smart contracts
- Initialize Firebase project with all required services
- Set up custom authentication for Solana wallets
- Establish event synchronization between Solana and Firestore

### Tasks

#### 1. Solana Contracts Setup

**In `contracts/` directory:**

**1.1 SparksToken Contract** (`contracts/sparks-token/`):
- [ ] Initialize Rust crate with Anchor framework
- [ ] Implement non-transferable token mint
- [ ] Functions:
  - `initialize_mint()`: Create mint with freeze authority
  - `mint_to()`: Mint tokens to user (non-transferable)
  - `get_balance()`: Query user balance
- [ ] Unit tests for minting and balance queries
- [ ] Error handling for invalid operations

**1.2 IdeaVault Contract** (`contracts/idea-vault/`):
- [ ] Initialize Anchor project
- [ ] Data structures:
  - Idea account (title, description, creator, status, spark_count, lives_remaining)
  - Status enum (Active, Graveyard, Revived)
- [ ] Functions:
  - `submit_idea()`: Create new idea (cost: 10 sparks)
  - `update_status()`: Transition between Active/Graveyard
  - `revive_idea()`: Revival logic with escalating costs (10 → 100 → 1000 → cap at 1000)
  - `check_lives()`: Verify 9 lives max per idea
- [ ] Unit tests for all state transitions
- [ ] Edge case handling (max lives, cost escalation)

**1.3 VotingEscrow Contract** (`contracts/voting-escrow/`):
- [ ] Initialize Anchor project
- [ ] Implement Stage 2 voting mechanism
- [ ] Functions:
  - `create_vote()`: Create vote (1:1 verified user requirement)
  - `cast_vote()`: Record vote with verification check
  - `get_vote_count()`: Query vote totals
- [ ] Integration with verified badge system
- [ ] Unit tests for voting logic

**1.4 RevivalLogic Contract** (`contracts/revival-logic/`):
- [ ] Initialize Anchor project
- [ ] Functions:
  - `transfer_ownership()`: Transfer idea ownership on revival
  - `increment_cat_counter()`: Track revival attempts
  - `check_revival_eligibility()`: Verify costs and lives
- [ ] Unit tests for ownership transfers

**1.5 RewardDistributor Contract** (`contracts/reward-distributor/`):
- [ ] Initialize Anchor project
- [ ] Functions:
  - `distribute_rewards()`: Calculate and distribute payouts
    - Creator: 2x multiplier
    - Other participants: 1.5x multiplier
  - `claim_rewards()`: Allow users to claim their rewards
- [ ] Unit tests for reward calculations

**1.6 Contract Integration**:
- [ ] Create integration tests for cross-contract calls
- [ ] Deploy to local Solana validator (`solana-test-validator`)
- [ ] Verify all contracts deploy successfully
- [ ] Test end-to-end flow: submit → stake → revive → vote → reward

#### 2. Firebase Setup

**2.1 Firebase Initialization**:
- [ ] Run `firebase init` with selections:
  - Firestore Database
  - Cloud Functions
  - Storage
  - Authentication
  - Hosting (for frontend)
- [ ] Configure `firebase.json` and `.firebaserc`
- [ ] Set up environment-specific configs (dev, staging, prod)

**2.2 Firestore Structure**:
Create collections with proper indexing:
```
users/
  {userId}/
    walletAddress: string
    verified: boolean
    profile: {...}
    createdAt: timestamp

ideas/
  {ideaId}/
    onChainId: string (Solana account)
    title: string
    description: string
    creatorId: string
    status: "active" | "graveyard" | "revived"
    sparkCount: number
    livesRemaining: number
    createdAt: timestamp
    updatedAt: timestamp

votes/
  {voteId}/
    ideaId: string
    voterId: string
    stage: number
    createdAt: timestamp

stakes/
  {stakeId}/
    ideaId: string
    stakerId: string
    amount: number
    verified: boolean
    createdAt: timestamp

committees/
  {committeeId}/
    name: string
    members: string[]
    proposals: string[]
    createdAt: timestamp
```

**2.3 Firestore Security Rules** (`firestore.rules`):
- [ ] Implement rules for:
  - Users: Read own data, write own profile
  - Ideas: Public read, authenticated write with validation
  - Votes: Authenticated write, verified users only for Stage 2
  - Stakes: Authenticated write, read own stakes
  - Committees: Authenticated read/write with membership checks
- [ ] Test rules with Firebase emulator

**2.4 Storage Rules** (`storage.rules`):
- [ ] Public read for public attachments
- [ ] Authenticated write with size/type validation
- [ ] Private folder access control
- [ ] Test with emulator

**2.5 Custom Authentication** (`backend/functions/src/auth/`):
- [ ] Create Cloud Function for Solana wallet authentication:
  - Signature verification (similar to Moralis/Crossmint approach)
  - JWT token generation
  - Custom claims (wallet address, verified status)
- [ ] Integration with Firebase Auth custom tokens
- [ ] Unit tests for signature verification

**2.6 Event Synchronization** (`backend/functions/src/sync/`):
- [ ] Cloud Function to listen to Solana events (via webhook or polling)
- [ ] Sync contract state to Firestore:
  - Idea submissions → Firestore ideas collection
  - Stakes → Firestore stakes collection
  - Votes → Firestore votes collection
  - Rewards → Update user balances
- [ ] Error handling and retry logic
- [ ] Idempotency checks to prevent duplicates

#### 3. Testing

**3.1 Contract Tests**:
- [ ] Run `anchor test` for all contracts
- [ ] Verify local validator integration
- [ ] Test error scenarios

**3.2 Firebase Tests**:
- [ ] Run Firebase emulators locally
- [ ] Test Firestore rules with emulator
- [ ] Test Storage rules with emulator
- [ ] Test authentication flow
- [ ] Test event synchronization

**3.3 Integration Tests**:
- [ ] End-to-end: Submit idea on-chain → Verify sync to Firestore
- [ ] End-to-end: Stake on-chain → Verify Firestore update
- [ ] End-to-end: Vote on-chain → Verify Firestore update

### Commit
```
Phase 1: Solana contracts and Firebase infrastructure

- Implemented SparksToken contract (non-transferable mint)
- Implemented IdeaVault contract with 9-lives revival logic
- Implemented VotingEscrow contract for Stage 2 voting
- Implemented RevivalLogic contract for ownership transfers
- Implemented RewardDistributor contract with creator/participant multipliers
- Initialized Firebase project with Firestore, Functions, Storage, Auth
- Created Firestore collections and security rules
- Implemented custom Solana wallet authentication via Cloud Functions
- Set up event synchronization from Solana to Firestore
- Added comprehensive unit and integration tests
- All contracts deployed and tested on local Solana validator
```

### Pause & Request
**Before proceeding to Phase 2, request:**
- [ ] Firebase project ID and API keys
- [ ] Solana RPC URL for devnet (or local validator confirmation)
- [ ] Solana keypair for devnet deployment
- [ ] myGovID API mock credentials (if available)
- [ ] Confirmation that contracts are working on local validator

---

## Phase 2: Core User Flows (Ideas, Staking, Revival, Voting)

### Objectives
- Build React Native frontend foundation
- Implement core idea lifecycle flows
- Integrate Solana wallet connectivity
- Create real-time chat functionality

### Tasks

#### 1. React Native Setup

**1.1 Project Initialization**:
- [ ] Initialize React Native project in `frontend/`
- [ ] Configure TypeScript
- [ ] Set up navigation (React Navigation)
- [ ] Configure state management (Redux Toolkit or Zustand)
- [ ] Set up theming and styling system

**1.2 Dependencies**:
Install and configure:
- [ ] `@solana/web3.js` - Solana blockchain interaction
- [ ] `@solana/wallet-adapter-react` - Wallet connection
- [ ] `@react-native-firebase/app` - Firebase core
- [ ] `@react-native-firebase/firestore` - Firestore
- [ ] `@react-native-firebase/auth` - Authentication
- [ ] `@react-native-firebase/storage` - Storage
- [ ] `react-native-gesture-handler` - Gestures
- [ ] `react-native-reanimated` - Animations
- [ ] Other required dependencies

**1.3 Project Structure**:
```
frontend/src/
├── screens/
│   ├── OnboardingScreen.tsx
│   ├── IdeaSubmissionScreen.tsx
│   ├── IdeaFeedScreen.tsx
│   ├── IdeaDetailScreen.tsx
│   ├── StakingScreen.tsx
│   └── VotingScreen.tsx
├── components/
│   ├── WalletConnectButton.tsx
│   ├── IdeaCard.tsx
│   ├── SparkCounter.tsx
│   ├── CatEmoji.tsx
│   └── Tooltip.tsx
├── services/
│   ├── solanaService.ts
│   ├── firebaseService.ts
│   ├── ideaService.ts
│   └── walletService.ts
├── hooks/
│   ├── useWallet.ts
│   ├── useIdeas.ts
│   └── useAuth.ts
├── utils/
│   ├── constants.ts
│   ├── formatters.ts
│   └── validators.ts
└── types/
    ├── idea.ts
    ├── user.ts
    └── wallet.ts
```

#### 2. Authentication & Wallet Integration

**2.1 Onboarding Screen**:
- [ ] Wallet connection UI (Phantom, Solflare, etc.)
- [ ] Firebase authentication flow
- [ ] Signature request and verification
- [ ] User profile creation (if new user)
- [ ] Navigation to main app

**2.2 Wallet Service** (`services/walletService.ts`):
- [ ] Connect/disconnect wallet functions
- [ ] Sign message functionality
- [ ] Transaction signing and sending
- [ ] Balance queries
- [ ] Error handling for wallet errors

**2.3 Auth Service** (`services/authService.ts`):
- [ ] Firebase Auth integration
- [ ] Custom token exchange (Solana signature → Firebase token)
- [ ] Auth state persistence
- [ ] Logout functionality

#### 3. Idea Submission Flow

**3.1 Idea Submission Screen**:
- [ ] Form fields:
  - Title (required, max 100 chars)
  - Description (required, max 2000 chars)
  - Category/tags (optional)
  - Tooltips explaining each field
- [ ] Spark cost display (10 sparks)
- [ ] Balance check before submission
- [ ] Submit button with loading state
- [ ] Success/error feedback

**3.2 Submission Logic** (`services/ideaService.ts`):
- [ ] Validate form data
- [ ] Check user balance (10 sparks minimum)
- [ ] Call Solana contract `submit_idea()`
- [ ] Wait for transaction confirmation
- [ ] Sync to Firestore (or wait for sync function)
- [ ] Update UI with new idea

#### 4. Idea Feed & Display

**4.1 Idea Feed Screen**:
- [ ] List view of ideas (active and graveyard)
- [ ] Filter options (active, graveyard, my ideas)
- [ ] Sort options (newest, most sparks, most votes)
- [ ] Pull-to-refresh
- [ ] Infinite scroll/pagination
- [ ] Real-time updates via Firestore listeners

**4.2 Idea Card Component**:
- [ ] Display: title, description preview, creator, spark count
- [ ] Cat emoji indicator (for graveyard ideas)
- [ ] Status badge (active/graveyard/revived)
- [ ] Tap to navigate to detail screen
- [ ] Styling with gradients/icons per inspiration

**4.3 Idea Detail Screen**:
- [ ] Full idea information
- [ ] Spark counter with staker list
- [ ] Life counter (X/9 lives remaining)
- [ ] Staking interface
- [ ] Voting interface (if Stage 2)
- [ ] Chat section (see below)
- [ ] Action buttons (revive, if applicable)

#### 5. Staking Flow

**5.1 Staking UI**:
- [ ] Input field for spark amount
- [ ] Balance display
- [ ] "Stake" button
- [ ] Verified badge indicator (1.5x multiplier info)
- [ ] Transaction status feedback

**5.2 Staking Logic**:
- [ ] Validate stake amount
- [ ] Check verified status for multiplier
- [ ] Call Solana contract to stake
- [ ] Update Firestore stake record
- [ ] Refresh idea spark count
- [ ] Show success message

#### 6. Revival Flow

**6.1 Revival UI**:
- [ ] Display current revival cost (escalating: 10 → 100 → 1000 → 1000)
- [ ] Show lives remaining (X/9)
- [ ] "Revive Idea" button
- [ ] Confirmation dialog
- [ ] Cost breakdown display

**6.2 Revival Logic**:
- [ ] Check eligibility (lives remaining, cost)
- [ ] Call Solana `revive_idea()` contract
- [ ] Handle ownership transfer
- [ ] Update idea status to "revived"
- [ ] Increment cat counter
- [ ] Update Firestore

#### 7. Voting Flow

**7.1 Voting UI** (Stage 2 only):
- [ ] Display vote options (if applicable)
- [ ] Vote button (disabled if not verified)
- [ ] Verified user requirement message
- [ ] Vote count display
- [ ] Real-time vote updates

**7.2 Voting Logic**:
- [ ] Verify user is authenticated and verified
- [ ] Check idea is in Stage 2
- [ ] Call Solana `cast_vote()` contract
- [ ] Update Firestore vote record
- [ ] Refresh vote counts

#### 8. Real-Time Chat

**8.1 Chat Component**:
- [ ] Firestore collection per idea: `ideas/{ideaId}/messages`
- [ ] Real-time message listener
- [ ] Message input with send button
- [ ] Message list with timestamps
- [ ] User avatars/names
- [ ] Staker-only access (enforce via Firestore rules)

**8.2 Chat Logic**:
- [ ] Verify user has staked on idea
- [ ] Create message document in Firestore
- [ ] Real-time updates via Firestore listeners
- [ ] Message validation (prevent spam)

#### 9. Testing

**9.1 Unit Tests**:
- [ ] Test all service functions
- [ ] Test form validations
- [ ] Test wallet connection logic
- [ ] Test calculation functions (spark costs, multipliers)

**9.2 Integration Tests**:
- [ ] End-to-end: Onboard → Submit idea → Verify on-chain and Firestore
- [ ] End-to-end: Stake on idea → Verify spark count update
- [ ] End-to-end: Revive idea → Verify status and cost escalation
- [ ] End-to-end: Vote on idea → Verify vote recorded
- [ ] End-to-end: Chat on idea → Verify message appears

**9.3 UI Tests**:
- [ ] Test navigation flows
- [ ] Test form submissions
- [ ] Test error states
- [ ] Test loading states

### Commit
```
Phase 2: Core idea and voting flows

- Initialized React Native project with TypeScript and navigation
- Implemented Solana wallet integration (Phantom, Solflare support)
- Created custom Firebase authentication for Solana wallets
- Built idea submission flow with 10-spark cost validation
- Implemented idea feed with real-time Firestore updates
- Added staking UI with verified user multiplier (1.5x)
- Implemented revival flow with escalating costs (10→100→1000→1000)
- Built Stage 2 voting interface with verified-only access
- Added real-time chat per idea (staker-only access)
- Comprehensive unit and integration tests
- UI styling with gradients and icons per design inspiration
```

### Pause & Request
**Before proceeding to Phase 3, request:**
- [ ] UI/UX feedback on screens (gradients, icons, layout)
- [ ] Confirmation that Solana devnet deployment is ready
- [ ] Any design adjustments based on inspiration image
- [ ] Test results from user testing (if available)

---

## Phase 3: Governance Features + User Profiles

### Objectives
- Implement committee creation and management
- Build internal election system
- Create user profile system with privacy controls
- Integrate verified badge system (myGovID mock)

### Tasks

#### 1. Governance: Committees

**1.1 Committee Creation**:
- [ ] Proposal screen for committee creation
- [ ] Form fields: name, description, initial members
- [ ] Submit as idea (goes through idea lifecycle)
- [ ] On approval, create committee in Firestore

**1.2 Committee Management Screen**:
- [ ] List of committees
- [ ] Committee detail view:
  - Members list
  - Proposals list
  - Activity feed
- [ ] Join/leave committee actions
- [ ] Member management (if admin)

#### 2. Governance: Internal Elections

**2.1 Election Creation**:
- [ ] Create election proposal (via idea submission)
- [ ] Configure: positions, candidates, voting period
- [ ] Nomination process (10 sparks to nominate)
- [ ] Candidate list display

**2.2 Election Voting**:
- [ ] Voting interface (similar to idea voting)
- [ ] Verified user requirement (1.5x multiplier for stakes)
- [ ] 1:1 verified votes (one vote per verified user)
- [ ] Real-time vote count
- [ ] Results display after voting period

**2.3 Election Logic** (`services/electionService.ts`):
- [ ] Nomination validation (10 sparks, user eligibility)
- [ ] Vote recording (verified users only)
- [ ] Threshold calculation (1.5x verified stakes)
- [ ] Winner determination
- [ ] Results announcement

#### 3. User Profiles

**3.1 Profile Screen**:
- [ ] Display sections:
  - Public info (always viewable): Name (mandatory), wallet address, voting records (on-chain/public)
  - Private info (user-controlled): Email, phone, personal details
- [ ] Edit profile button (for own profile)
- [ ] Privacy toggle for private fields
- [ ] Verified badge display (if verified)

**3.2 Profile Form**:
- [ ] Name field (required)
- [ ] Optional fields with privacy toggles
- [ ] Profile picture upload (Firebase Storage)
- [ ] Save/cancel actions
- [ ] Validation

**3.3 Voting Records Display**:
- [ ] List of on-chain votes (public)
- [ ] Link to voted ideas/elections
- [ ] Vote history timeline
- [ ] Statistics (total votes, participation rate)

#### 4. Verified Badge System

**4.1 myGovID Integration (Mock)**:
- [ ] Mock API service (`services/mygovidService.ts`)
- [ ] Verification request flow
- [ ] Mock verification response
- [ ] Update user verified status in Firestore
- [ ] Update custom claims in Firebase Auth

**4.2 Verified Badge UI**:
- [ ] Badge component (display throughout app)
- [ ] Verification status indicator
- [ ] "Verify Now" CTA for unverified users
- [ ] Verification process screen

#### 5. Testing

**5.1 Unit Tests**:
- [ ] Committee creation logic
- [ ] Election nomination and voting
- [ ] Profile update logic
- [ ] Verified badge assignment

**5.2 Integration Tests**:
- [ ] End-to-end: Create committee → Verify creation
- [ ] End-to-end: Nominate candidate → Vote → Verify results
- [ ] End-to-end: Update profile → Verify privacy settings
- [ ] End-to-end: Verify user → Verify badge appears

### Commit
```
Phase 3: Governance features and user profiles

- Implemented committee creation via idea proposals
- Built committee management screens with member/proposal lists
- Created internal election system with nomination (10 sparks) and voting
- Implemented verified-only voting (1:1) with 1.5x stake multiplier
- Built user profile system with public/private field controls
- Added voting records display (on-chain, public)
- Integrated myGovID mock API for verified badge system
- Added verified badge UI components throughout app
- Comprehensive tests for governance and profile features
```

### Pause & Request
**Before proceeding to Phase 4, request:**
- [ ] Sample data for testing (mock profiles, committees)
- [ ] Confirmation of myGovID API integration approach (mock vs real)
- [ ] Any additional profile fields needed
- [ ] Feedback on governance flows

---

## Phase 4: Projects & Attachments

### Objectives
- Implement project creation from policies
- Build attachment system with public/private controls
- Add moderation capabilities for verified users

### Tasks

#### 1. Project System

**1.1 Project Creation**:
- [ ] "Spawn Project" action from policy ideas
- [ ] Project form:
  - Name, description
  - Tasks/deadlines
  - Committee assignment (dropdown)
  - Status (planning, in-progress, completed)
- [ ] Create project in Firestore
- [ ] Link to source policy idea

**1.2 Project Management Screen**:
- [ ] List of projects (filter by committee, status)
- [ ] Project detail view:
  - Tasks list with deadlines
  - Progress indicators
  - Committee members
  - Attachments section
  - Activity log

**1.3 Task Management**:
- [ ] Add/edit/delete tasks
- [ ] Assign tasks to committee members
- [ ] Set deadlines
- [ ] Mark tasks complete
- [ ] Progress calculation

#### 2. Attachments System

**2.1 Attachment Upload**:
- [ ] Upload UI (camera, file picker)
- [ ] File type validation (images, PDFs, documents)
- [ ] Size limits (configurable, e.g., 10MB max)
- [ ] Public/private dropdown selector
- [ ] Upload to Firebase Storage
- [ ] Create metadata in Firestore

**2.2 Attachment Display**:
- [ ] List of attachments per project/idea
- [ ] Public attachments: visible to all
- [ ] Private attachments: visible to committee/verified users only
- [ ] Preview for images/PDFs
- [ ] Download functionality
- [ ] Delete/edit (with permissions)

**2.3 Attachment Metadata** (`firestore`):
```
attachments/
  {attachmentId}/
    projectId: string (or ideaId)
    fileName: string
    fileType: string
    fileSize: number
    storagePath: string
    isPublic: boolean
    uploadedBy: string
    uploadedAt: timestamp
    accessControl: {
      committeeOnly: boolean
      verifiedOnly: boolean
    }
```

#### 3. Moderation

**3.1 Verified Moderation**:
- [ ] Moderation UI (for verified users)
- [ ] Actions: approve, reject, flag
- [ ] Moderation log
- [ ] Notification system for moderation actions

**3.2 Access Control**:
- [ ] Enforce private attachment visibility rules
- [ ] Committee-only access for private project elements
- [ ] Verified-only access for sensitive content
- [ ] Firestore rules for attachment access

#### 4. Testing

**4.1 Unit Tests**:
- [ ] Project creation logic
- [ ] Task management functions
- [ ] Attachment upload/access logic
- [ ] Moderation functions

**4.2 Integration Tests**:
- [ ] End-to-end: Spawn project from policy → Verify creation
- [ ] End-to-end: Upload public attachment → Verify visibility
- [ ] End-to-end: Upload private attachment → Verify access control
- [ ] End-to-end: Moderate content → Verify action applied

### Commit
```
Phase 4: Projects and attachments system

- Implemented project spawning from policy ideas
- Built project management with tasks, deadlines, committee assignment
- Created attachment upload system with public/private controls
- Added Firebase Storage integration with metadata in Firestore
- Implemented access control for private attachments (committee/verified-only)
- Added verified user moderation capabilities
- Comprehensive tests for projects and attachments
- Updated Firestore rules for attachment access control
```

### Pause & Request
**Before proceeding to Phase 5, request:**
- [ ] Storage bucket configuration confirmation
- [ ] File size/type limits preferences
- [ ] Any additional project fields needed
- [ ] Moderation workflow feedback

---

## Phase 5: Dashboards & Analytics

### Objectives
- Build data visualization dashboards
- Implement electorate trend analysis
- Create export functionality for reports

### Tasks

#### 1. Dashboard Module Setup

**1.1 Dashboard Structure**:
- [ ] Create dashboard screen/module
- [ ] Navigation to dashboard
- [ ] Tab/section navigation within dashboard
- [ ] Responsive layout (mobile/tablet/web)

**1.2 Data Aggregation**:
- [ ] Cloud Functions for data aggregation:
  - Electorate trends
  - Idea statistics
  - Voting patterns
  - User engagement metrics
- [ ] Scheduled functions for daily/weekly aggregations
- [ ] Cache aggregated data in Firestore

#### 2. D3.js Visualizations

**2.1 Electorate Trends**:
- [ ] Line/area chart showing idea submissions by electorate over time
- [ ] Bar chart for top electorates by engagement
- [ ] Map visualization (if geolocation data available)
- [ ] Filter by time period (week, month, year)

**2.2 Idea Analytics**:
- [ ] Pie chart: Ideas by status (active/graveyard/revived)
- [ ] Bar chart: Top ideas by spark count
- [ ] Timeline: Idea lifecycle visualization
- [ ] Spark distribution histogram

**2.3 Voting Analytics**:
- [ ] Turnout rates by electorate
- [ ] Vote distribution charts
- [ ] Participation trends over time
- [ ] Verified vs non-verified voter breakdown

**2.4 User Engagement**:
- [ ] Active users over time
- [ ] User participation heatmap
- [ ] Top contributors list
- [ ] Engagement score trends

#### 3. Data Queries

**3.1 Firestore Queries**:
- [ ] Optimize queries with proper indexing
- [ ] Composite indexes for complex queries
- [ ] Pagination for large datasets
- [ ] Real-time updates for live dashboards

**3.2 On-Chain Data Sync**:
- [ ] Cloud Function to aggregate on-chain data
- [ ] Periodic sync jobs
- [ ] Store aggregated metrics in Firestore
- [ ] Handle sync errors gracefully

#### 4. Export Functionality

**4.1 Report Generation**:
- [ ] Export dashboard data as CSV
- [ ] Export as PDF (with charts)
- [ ] Scheduled email reports (optional)
- [ ] Custom date range selection

**4.2 Export Service** (`services/exportService.ts`):
- [ ] CSV generation
- [ ] PDF generation (with charts)
- [ ] File download functionality
- [ ] Error handling

#### 5. Performance Optimization

**5.1 Query Optimization**:
- [ ] Add Firestore composite indexes
- [ ] Implement data pagination
- [ ] Cache frequently accessed data
- [ ] Lazy load dashboard sections

**5.2 Visualization Performance**:
- [ ] Optimize D3.js rendering for large datasets
- [ ] Implement data sampling for very large datasets
- [ ] Use virtual scrolling for lists
- [ ] Debounce filter inputs

#### 6. Testing

**6.1 Unit Tests**:
- [ ] Data aggregation functions
- [ ] Chart data transformation
- [ ] Export generation functions

**6.2 Integration Tests**:
- [ ] End-to-end: Load dashboard → Verify charts render
- [ ] End-to-end: Filter by electorate → Verify data updates
- [ ] End-to-end: Export report → Verify file generation

### Commit
```
Phase 5: Dashboards and analytics module

- Built dashboard module with D3.js visualizations
- Implemented electorate trend analysis with line/bar charts
- Created idea analytics (status distribution, spark counts, lifecycle)
- Added voting analytics (turnout, participation, verified breakdown)
- Built user engagement metrics and heatmaps
- Optimized Firestore queries with composite indexes
- Implemented on-chain data aggregation via Cloud Functions
- Added export functionality (CSV, PDF) for reports
- Performance optimizations for large datasets
- Comprehensive tests for dashboard and export features
```

### Pause & Request
**Before proceeding to Phase 6, request:**
- [ ] Specific metric requirements or adjustments
- [ ] Additional visualization types needed
- [ ] Export format preferences
- [ ] Performance benchmarks to meet

---

## Phase 6: Testing, Hardening & Deployment

### Objectives
- Comprehensive testing suite
- Security audit and hardening
- Performance optimization
- Production deployment

### Tasks

#### 1. Comprehensive Testing

**1.1 Contract Tests**:
- [ ] Unit tests for all Solana contracts (100% coverage target)
- [ ] Integration tests for cross-contract interactions
- [ ] Edge case testing (max values, boundary conditions)
- [ ] Security tests (reentrancy, overflow, access control)
- [ ] Gas optimization verification

**1.2 Frontend Tests**:
- [ ] Unit tests for all components (Jest + React Native Testing Library)
- [ ] Integration tests for user flows
- [ ] E2E tests (Detox or similar)
- [ ] Snapshot tests for UI components
- [ ] Accessibility tests (a11y)

**1.3 Backend Tests**:
- [ ] Unit tests for Cloud Functions
- [ ] Integration tests with Firebase emulators
- [ ] Security rule tests
- [ ] Performance tests (load testing)

**1.4 Test Coverage**:
- [ ] Aim for 80%+ code coverage
- [ ] Generate coverage reports
- [ ] Document test strategy

#### 2. Security Hardening

**2.1 Smart Contract Security**:
- [ ] Audit contract code for vulnerabilities
- [ ] Implement access controls
- [ ] Add input validation
- [ ] Test for common exploits (reentrancy, overflow, etc.)
- [ ] Consider formal verification for critical contracts

**2.2 Application Security**:
- [ ] Input sanitization (XSS prevention)
- [ ] SQL injection prevention (N/A for Firestore, but validate queries)
- [ ] Authentication token security
- [ ] API rate limiting
- [ ] CORS configuration
- [ ] Environment variable security (no secrets in code)

**2.3 Firebase Security**:
- [ ] Review and tighten Firestore rules
- [ ] Review and tighten Storage rules
- [ ] Implement Cloud Functions authentication
- [ ] Set up Firebase App Check
- [ ] Configure CORS for Cloud Functions

**2.4 Dependency Security**:
- [ ] Run `npm audit` and fix vulnerabilities
- [ ] Run `cargo audit` for Rust dependencies
- [ ] Keep dependencies updated
- [ ] Use Dependabot or similar for automated updates

#### 3. Error Handling & Logging

**3.1 Error Handling**:
- [ ] Comprehensive try-catch blocks
- [ ] User-friendly error messages
- [ ] Error boundaries in React Native
- [ ] Graceful degradation for failed features
- [ ] Retry logic for network requests

**3.2 Logging**:
- [ ] Structured logging in Cloud Functions
- [ ] Error tracking (Sentry or similar)
- [ ] Analytics events (Firebase Analytics)
- [ ] Performance monitoring
- [ ] Log retention policies

#### 4. Performance Optimization

**4.1 Frontend Performance**:
- [ ] Code splitting and lazy loading
- [ ] Image optimization
- [ ] Bundle size optimization
- [ ] Memoization for expensive computations
- [ ] Virtual scrolling for long lists
- [ ] Optimize re-renders (React.memo, useMemo)

**4.2 Backend Performance**:
- [ ] Optimize Cloud Functions (cold start reduction)
- [ ] Firestore query optimization
- [ ] Implement caching where appropriate
- [ ] Batch operations where possible
- [ ] Index optimization

**4.3 Blockchain Performance**:
- [ ] Optimize contract calls (batch transactions)
- [ ] Reduce transaction sizes
- [ ] Implement transaction queuing
- [ ] Handle network congestion gracefully

#### 5. UI/UX Polish

**5.1 Design Refinement**:
- [ ] Apply gradients and icons per inspiration
- [ ] Consistent color scheme
- [ ] Typography hierarchy
- [ ] Spacing and layout consistency
- [ ] Loading states and skeletons
- [ ] Empty states
- [ ] Error states

**5.2 Accessibility**:
- [ ] Screen reader support
- [ ] Keyboard navigation
- [ ] Color contrast compliance (WCAG AA)
- [ ] Focus indicators
- [ ] Alt text for images
- [ ] ARIA labels where needed

**5.3 Responsive Design**:
- [ ] Mobile-first approach
- [ ] Tablet layouts
- [ ] Web/desktop layouts
- [ ] Test on various screen sizes

#### 6. Documentation

**6.1 Code Documentation**:
- [ ] JSDoc/TSDoc for all public functions
- [ ] Inline comments for complex logic
- [ ] README updates with latest features
- [ ] API documentation

**6.2 User Documentation**:
- [ ] User guide (how to submit ideas, vote, etc.)
- [ ] FAQ
- [ ] Troubleshooting guide

**6.3 Developer Documentation**:
- [ ] Architecture documentation
- [ ] Setup guide
- [ ] Deployment guide
- [ ] Contributing guide updates

#### 7. Deployment

**7.1 Pre-Deployment Checklist**:
- [ ] All tests passing
- [ ] Security audit complete
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Environment variables configured
- [ ] Backup strategy in place

**7.2 Solana Deployment**:
- [ ] Deploy contracts to devnet
- [ ] Verify contract addresses
- [ ] Test on devnet
- [ ] Prepare for mainnet (when ready)
- [ ] Document contract addresses

**7.3 Firebase Deployment**:
- [ ] Deploy Cloud Functions
- [ ] Deploy Firestore rules
- [ ] Deploy Storage rules
- [ ] Deploy hosting (if using)
- [ ] Configure custom domains (if needed)
- [ ] Set up monitoring/alerts

**7.4 Frontend Deployment**:
- [ ] Build production bundles
- [ ] Test production build locally
- [ ] Deploy to Firebase Hosting (web)
- [ ] Build and test iOS app
- [ ] Build and test Android app
- [ ] Submit to app stores (if applicable)

**7.5 Post-Deployment**:
- [ ] Smoke tests on production
- [ ] Monitor error rates
- [ ] Monitor performance metrics
- [ ] Set up alerts for critical issues
- [ ] Document deployment process

#### 8. Monitoring & Maintenance

**8.1 Monitoring Setup**:
- [ ] Firebase Performance Monitoring
- [ ] Error tracking (Sentry)
- [ ] Analytics (Firebase Analytics)
- [ ] Uptime monitoring
- [ ] Alert configuration

**8.2 Maintenance Plan**:
- [ ] Regular dependency updates
- [ ] Security patches
- [ ] Performance reviews
- [ ] User feedback collection
- [ ] Bug triage process

### Commit
```
Phase 6: Testing, hardening, and MVP deployment

- Comprehensive test suite: contracts (100% coverage), frontend (80%+), backend
- Security hardening: contract audits, input validation, access controls
- Performance optimizations: code splitting, query optimization, caching
- UI/UX polish: gradients, icons, accessibility (WCAG AA), responsive design
- Complete documentation: code docs, user guide, deployment guide
- Deployed contracts to Solana devnet
- Deployed Firebase infrastructure (Functions, Firestore, Storage, Hosting)
- Production builds for web, iOS, Android
- Monitoring and alerting configured
- All pre-deployment checks passed
```

### Final Summary

After Phase 6 completion, output:

```
✅ MVP COMPLETE

Repository: https://github.com/cryptonut/open-integrity.git
Status: All phases complete, deployed to devnet

What was built:
- Solana smart contracts (5 contracts: SparksToken, IdeaVault, VotingEscrow, RevivalLogic, RewardDistributor)
- React Native frontend (cross-platform)
- Firebase backend (Firestore, Functions, Storage, Auth)
- Core flows: Idea submission, staking, revival, voting
- Governance: Committees, elections
- Projects and attachments system
- Dashboards with D3.js visualizations
- Comprehensive testing and security hardening

Deployment:
- Solana contracts: [devnet addresses]
- Firebase project: [project ID]
- Web app: [URL]
- iOS/Android: [build status]

Next steps:
1. User acceptance testing
2. Mainnet deployment (when ready)
3. App store submissions
4. Marketing and user acquisition
5. Iterate based on feedback

Questions or issues? Check docs/ or open an issue.
```

### Pause & Request
**Final requests:**
- [ ] User acceptance testing feedback
- [ ] Approval for mainnet deployment (when ready)
- [ ] App store submission requirements (if applicable)
- [ ] Any additional features or adjustments needed

---

## Additional Guidelines

### Code Quality Standards
- **TypeScript**: Strict mode enabled, no `any` types
- **Rust**: Follow Rust best practices, use `clippy` for linting
- **Testing**: Minimum 80% code coverage
- **Documentation**: All public APIs documented
- **Formatting**: Automatic formatting on commit (Prettier, rustfmt)

### Git Workflow
- **Branches**: `main` (production), `develop` (integration), `feature/*` (features)
- **Commits**: Conventional commits format
- **PRs**: Required for all changes, must pass CI
- **Reviews**: At least one approval before merge

### Error Handling
- Never silently fail—always log errors
- User-friendly error messages
- Graceful degradation
- Retry logic for transient failures

### Security Best Practices
- Never commit secrets (use environment variables)
- Validate all user inputs
- Use parameterized queries (Firestore handles this)
- Implement rate limiting
- Regular security audits

### Performance Targets
- First Contentful Paint: < 2s
- Time to Interactive: < 3s
- Firestore query latency: < 100ms (p95)
- Solana transaction confirmation: < 30s (network dependent)

---

## Troubleshooting

If you encounter issues:

1. **Contract deployment fails**: Check Solana CLI version, RPC endpoint, keypair permissions
2. **Firebase init fails**: Verify Firebase CLI is installed and authenticated
3. **React Native build fails**: Check Node.js version, clear cache, reinstall dependencies
4. **Tests fail**: Verify emulators are running, check test data setup
5. **Sync issues**: Check Cloud Functions logs, verify event listeners are active

Always document errors and solutions in `docs/TROUBLESHOOTING.md`.

---

## Success Criteria

The MVP is complete when:
- ✅ All 6 phases executed successfully
- ✅ All tests passing (80%+ coverage)
- ✅ Security audit passed
- ✅ Deployed to devnet/staging
- ✅ Documentation complete
- ✅ User can complete full flow: onboard → submit idea → stake → vote → see results

---

**Ready to begin? Start with Phase 0 and proceed sequentially. Good luck! 🚀**
