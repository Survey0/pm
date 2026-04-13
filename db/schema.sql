-- =============================================
-- SURVEY PLATFORM DATABASE SCHEMA
-- Anonymous respondents, authenticated owners
-- =============================================

CREATE DATABASE IF NOT EXISTS survey_platform
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE survey_platform;

-- =============================================
-- 1. USERS table (survey owners/creators only)
-- =============================================
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    login VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    salt VARCHAR(64) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_login (login),
    UNIQUE KEY uk_users_email (email),
    INDEX idx_users_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- 2. SURVEYS table (owned by users)
-- =============================================
CREATE TABLE surveys (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,  -- Owner/creator
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at DATE NOT NULL,
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP NULL,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id),
    INDEX idx_surveys_user_id (user_id),
    INDEX idx_surveys_created_at (created_at),
    
    CONSTRAINT fk_surveys_user_id
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- 3. QUESTIONS table
-- =============================================
CREATE TABLE questions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    survey_id BIGINT UNSIGNED NOT NULL,
    position INT NOT NULL DEFAULT 0,
    question_text TEXT NOT NULL,
    type VARCHAR(20) NOT NULL,  -- 'SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TEXT'
    is_required BOOLEAN DEFAULT FALSE,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id),
    INDEX idx_questions_survey_id (survey_id),
    INDEX idx_questions_survey_position (survey_id, position),
    
    CONSTRAINT fk_questions_survey_id
        FOREIGN KEY (survey_id) REFERENCES surveys(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_questions_type CHECK (
        type IN ('SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TEXT')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- 4. OPTIONS table (for single/multiple choice questions)
-- =============================================
CREATE TABLE options (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    question_id BIGINT UNSIGNED NOT NULL,
    position INT NOT NULL DEFAULT 0,
    option_text VARCHAR(500) NOT NULL,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id),
    INDEX idx_options_question_id (question_id),
    INDEX idx_options_question_position (question_id, position),
    
    CONSTRAINT fk_options_question_id
        FOREIGN KEY (question_id) REFERENCES questions(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- 5. RESPONSES table (anonymous responses)
-- Each response session = one user completing one survey
-- =============================================
CREATE TABLE responses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    survey_id BIGINT UNSIGNED NOT NULL,
    respondent_session_id VARCHAR(64) NOT NULL,  -- UUID or session token for anonymous respondent
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    
    PRIMARY KEY (id),
    INDEX idx_responses_survey_id (survey_id),
    INDEX idx_responses_session (respondent_session_id),
    INDEX idx_responses_survey_session (survey_id, respondent_session_id),
    INDEX idx_responses_completed (is_completed, completed_at),
    
    CONSTRAINT fk_responses_survey_id
        FOREIGN KEY (survey_id) REFERENCES surveys(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- 6. ANSWERS table (individual question answers)
-- Each answer belongs to a response session
-- =============================================
CREATE TABLE answers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    response_id BIGINT UNSIGNED NOT NULL,     -- Links to the response session
    question_id BIGINT UNSIGNED NOT NULL,     -- Which question was answered
    option_id BIGINT UNSIGNED NULL,           -- For choice questions
    answer_text TEXT NULL,                    -- For TEXT questions or "other" option
    answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (id),
    INDEX idx_answers_response_id (response_id),
    INDEX idx_answers_question_id (question_id),
    INDEX idx_answers_option_id (option_id),
    INDEX idx_answers_response_question (response_id, question_id),
    
    CONSTRAINT fk_answers_response_id
        FOREIGN KEY (response_id) REFERENCES responses(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_answers_question_id
        FOREIGN KEY (question_id) REFERENCES questions(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_answers_option_id
        FOREIGN KEY (option_id) REFERENCES options(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    -- Ensure either option_id OR answer_text is provided
    CONSTRAINT chk_answers_content CHECK (
        (option_id IS NOT NULL AND answer_text IS NULL) OR
        (option_id IS NULL AND answer_text IS NOT NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================
-- Sample data
-- =============================================
INSERT INTO users (login, email, salt, password_hash) VALUES
('admin', 'admin@example.com', 'randomsalt123', 'hashed_password_example');

INSERT INTO surveys (user_id, name, description, created_at, is_published, shareable_link) VALUES
(1, 'My awesome survey', 'This is my first survey designed in Figma', CURDATE(), TRUE, 'abc123def456');

INSERT INTO questions (survey_id, position, question_text, type, is_required) VALUES
(1, 1, 'Do you like surveys?', 'SINGLE_CHOICE', TRUE),
(1, 2, 'What do you like about new office?', 'MULTIPLE_CHOICE', TRUE),
(1, 3, 'Please provide any information you want in free form', 'TEXT', FALSE);

INSERT INTO options (question_id, position, option_text) VALUES
(1, 1, 'Yes'),
(1, 2, 'No'),
(1, 3, 'Hard to say'),
(2, 1, 'Water cooler'),
(2, 2, 'Coffee machine'),
(2, 3, 'Bed'),
(2, 4, 'Vending machines');

-- Example anonymous response
INSERT INTO responses (survey_id, respondent_session_id, completed_at, is_completed) VALUES
(1, 'session_xyz789', NOW(), TRUE);

INSERT INTO answers (response_id, question_id, option_id, answer_text) VALUES
(1, 1, 1, NULL),  -- Selected "Yes"
(1, 2, 4, NULL),  -- Selected "Vending machines"
(1, 3, NULL, 'This is my free text feedback!');