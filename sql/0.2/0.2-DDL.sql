
USE `runelight`;


DROP TABLE IF EXISTS `account_ticketingMessages`;
DROP TABLE IF EXISTS `account_ticketingTopics`;


CREATE TABLE `account_ticketingTopics` (
	`id`			INT(10)		UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE, 
	
	PRIMARY KEY (`id`)
) ENGINE=InnoDB;


CREATE TABLE `account_ticketingMessages` (
	`id`				BIGINT(20)		UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE, 
	`topicId`			INT(10)			UNSIGNED NOT NULL, 
	`title`				VARCHAR(54)		NOT NULL,
	`messageNum`		SMALLINT(5)		UNSIGNED NOT NULL, 
	`date`				DATETIME		NOT NULL, 
	`message`			TEXT			NOT NULL, 
	`authorName`		VARCHAR(12)		NOT NULL, 
	`authorStaff`		BIT				NOT NULL, 
	`authorIP`			VARCHAR(128)	NOT NULL, 
	`actualAuthorId`	INT(10)			NOT NULL,
	`receiverName`		VARCHAR(12)		NULL, 
	`canReply`			BIT				NOT NULL,
	`authorDelete`		BIT				NOT NULL DEFAULT 0, 
	`receiverDelete`	BIT				NOT NULL DEFAULT 0, 
	`readOn`			DATETIME		NULL,
	`includeTitleInMsg`	BIT				NOT NULL DEFAULT 0,
	
	PRIMARY KEY (`id`), 
	FOREIGN KEY (`topicId`) REFERENCES `account_ticketingTopics` (`id`)
) ENGINE=InnoDB;



DELIMITER $$ 


DROP PROCEDURE IF EXISTS `staff_ticketingMarkActioned` $$
CREATE PROCEDURE `staff_ticketingMarkActioned` (
	IN `in_id`			BIGINT(20),
	IN `in_username`	VARCHAR(12),
	IN `in_date`		DATETIME
) 
BEGIN 
	UPDATE `account_ticketingMessages` 
	SET `receiverName` = `in_username`, 
		`readOn` = `in_date` 
	WHERE `id` = `in_id` 
	LIMIT 1;
END $$


DROP PROCEDURE IF EXISTS `staff_ticketingGetTicket` $$
CREATE PROCEDURE `staff_ticketingGetTicket` (
	IN `in_id`		BIGINT(20)
) 
BEGIN 
	SELECT `topicId`, `title`, `date`, `message`, `authorName`, `authorIP`, `actualAuthorId` 
	FROM `account_ticketingMessages` 
	WHERE `receiverName` IS NULL 
		AND `receiverDelete` = 0 
		AND `id` = `in_id` 
	LIMIT 1;
END $$


DROP PROCEDURE IF EXISTS `staff_ticketingGetOpenTickets` $$
CREATE PROCEDURE `staff_ticketingGetOpenTickets` () 
BEGIN 
	SELECT `id`, `title`, `authorName`, `actualAuthorId`, `date` 
	FROM `account_ticketingMessages` 
	WHERE `receiverName` IS NULL 
		AND `receiverDelete` = 0 
	ORDER BY `date` ASC;
END $$


DROP PROCEDURE IF EXISTS `staff_ticketingGetOpenTicketCount` $$
CREATE PROCEDURE `staff_ticketingGetOpenTicketCount` (
	OUT `out_count`		INT(10)	
) 
BEGIN 
	SELECT COUNT(`id`) INTO `out_count` 
	FROM `account_ticketingMessages` 
	WHERE `receiverName` IS NULL 
		AND `receiverDelete` = 0;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingGetUnreadCount` $$
CREATE PROCEDURE `account_ticketingGetUnreadCount` (
	IN `in_username`	VARCHAR(12),
	OUT `out_count`		INT(10)	
) 
BEGIN 
	SELECT COUNT(`id`) INTO `out_count` 
	FROM `account_ticketingMessages` 
	WHERE `receiverName` = `in_username` 
		AND `readOn` IS NULL 
		AND `receiverDelete` = 0;
END $$
	
	
DROP PROCEDURE IF EXISTS `account_ticketingActivityCheck` $$
CREATE PROCEDURE `account_ticketingActivityCheck` (
	IN `in_username`	VARCHAR(12),
	IN `in_ip`			VARCHAR(128),
	IN `in_minDate`		DATETIME,
	OUT `out_count`		TINYINT(1)
) 
BEGIN 
	SELECT COUNT(`id`) INTO `out_count` 
	FROM `account_ticketingMessages` 
	WHERE `receiverName` IS NULL 
		AND (
			`authorName` = `in_username` 
			OR 
			`authorIP` = `in_ip` 
		) 
		AND `date` > `in_minDate` 
	LIMIT 1;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingSendMessage` $$
CREATE PROCEDURE `account_ticketingSendMessage` (
	IN `in_isReply`				BIT,
	IN `in_topicId`				INT(10), 
	IN `in_title`				VARCHAR(54),
	IN `in_messageNum`			SMALLINT(5),
	IN `in_date`				DATETIME, 
	IN `in_message`				TEXT, 
	IN `in_author`				VARCHAR(12),
	IN `in_authorStaff`			BIT,
	IN `in_authorIP`			VARCHAR(128),
	IN `in_authorId`			INT(10),
	IN `in_receiver`			VARCHAR(12),
	IN `in_canReply`			BIT,
	IN `in_includeTitleInMsg`	BIT,
	OUT `out_successful`		BIT
) 
BEGIN 
	DECLARE `newTopicId` INT(10) UNSIGNED;
	IF (`in_isReply` = 0) THEN 
		INSERT INTO `account_ticketingTopics` () VALUES ();
		
		SET `newTopicId` = LAST_INSERT_ID();
	ELSE 
		SET `newTopicId` = `in_topicId`;
	END IF;
	
	INSERT INTO `account_ticketingMessages` (
		`topicId`, `title`, `messageNum`, `date`, `message`, `authorName`, `authorStaff`, `authorIP`, `actualAuthorId`, `receiverName`, `canReply`, `includeTitleInMsg` 
	) VALUES (
		`newTopicId`, `in_title`, `in_messageNum`, `in_date`, `in_message`, `in_author`, `in_authorStaff`, `in_authorIP`, `in_authorId`, `in_receiver`, `in_canReply`, `in_includeTitleInMsg` 
	);
	
	IF (ROW_COUNT() < 1) THEN
		SET `out_successful` = 0;
	ELSE
		SET `out_successful` = 1;
	END IF;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingDeleteMessage` $$ 
CREATE PROCEDURE `account_ticketingDeleteMessage` (
	IN `in_id`				BIGINT(20),
	IN `in_username`		VARCHAR(12),
	OUT `out_successful`	BIT
) 
BEGIN 
	DECLARE `author`	 VARCHAR(12) DEFAULT NULL;
	DECLARE `receiver`	 VARCHAR(12) DEFAULT NULL;
	
	SELECT `authorName`, `receiverName` INTO `author`, `receiver` 
	FROM `account_ticketingMessages` 
	WHERE `id` = `in_id` 
		AND (`authorName` = `in_username` OR `receiverName` = `in_username`)  
	LIMIT 1;
	
	IF (`author` IS NOT NULL) THEN 
		IF (`author` = `in_username`) THEN 
			UPDATE `account_ticketingMessages` 
			SET `authorDelete` = 1 
			WHERE `id` = `in_id` 
			LIMIT 1;
		ELSEIF (`receiver` = `in_username`) THEN 
			UPDATE `account_ticketingMessages` 
			SET `receiverDelete` = 1 
			WHERE `id` = `in_id` 
			LIMIT 1;
		END IF; 
		
		IF (ROW_COUNT() < 1) THEN 
			SET `out_successful` = 0;
		ELSE 
			SET `out_successful` = 1;
		END IF;
	ELSE 
		SET `out_successful` = 0;
	END IF;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingCheckMessageId` $$
CREATE PROCEDURE `account_ticketingCheckMessageId` (
	IN `in_id`				BIGINT(20),
	IN `in_username`		VARCHAR(12)
) 
BEGIN 
	SELECT `authorName`, `receiverName`, `authorDelete`, `receiverDelete`  
	FROM `account_ticketingMessages` 
	WHERE `id` = `in_id` 
	LIMIT 1;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingGetThread` $$
CREATE PROCEDURE `account_ticketingGetThread` (
	IN `in_id`				BIGINT(20),
	IN `in_username`		VARCHAR(12), 
	IN `in_date`			DATETIME, 
	OUT `out_topicId`		INT(10),
	OUT `out_messageNum`	SMALLINT(5),
	OUT `out_mainTitle`		VARCHAR(50), 
	OUT `out_canReply`		BIT,
	OUT `out_authorName`	VARCHAR(12)
) 
BEGIN 
	DECLARE `lastMessageId` BIGINT(20);
	
	SELECT `topicId`, `messageNum`, `title`, `canReply`, `authorName` 
		INTO `out_topicId`, `out_messageNum`, `out_mainTitle`, `out_canReply`, `out_authorName` 
	FROM `account_ticketingMessages` 
	WHERE `id` = `in_id` 
		AND (
			(`authorName` = `in_username` AND `authorDelete` = 0) 
			OR 
			(`receiverName` = `in_username` AND `receiverDelete` = 0)
		)
	LIMIT 1;
	
	IF (`out_topicId` > 0) THEN 
		SELECT `id` INTO `lastMessageId` 
		FROM `account_ticketingMessages` 
		WHERE `topicId` = `out_topicId` 
		ORDER BY `date` DESC 
		LIMIT 1;
		
		IF (`in_id` = `lastMessageId`) THEN 
			SELECT `id`, `title`, `date`, `message`, `authorName`, `authorStaff`, `readOn`, `includeTitleInMsg` 
			FROM `account_ticketingMessages` 
			WHERE `topicId` = `out_topicId` 
				AND `messageNum` <= `out_messageNum` 
			ORDER BY `date` ASC;
			
			-- Set post to READ.
			IF (`in_username` != `out_authorName`) THEN 
				UPDATE `account_ticketingMessages` 
				SET `readOn` = `in_date` 
				WHERE `topicId` = `out_topicId` 
					AND `messageNum` = `out_messageNum` 
				LIMIT 1;
			END IF;
		END IF;
	END IF;
END $$


DROP PROCEDURE IF EXISTS `account_ticketingGetMessageQueue` $$
CREATE PROCEDURE `account_ticketingGetMessageQueue` (
	IN `in_username`	VARCHAR(12)
) 
BEGIN 
	SELECT `id`, `title`, `date`, `messageNum`, `authorName`, `receiverName`, `authorDelete`, `receiverDelete`, `readOn` 
	FROM `account_ticketingMessages` 
	WHERE `id` IN (
		SELECT MAX(`id`) 
		FROM `account_ticketingMessages` 
		GROUP BY `topicId` 
	)
	ORDER BY `date` DESC;
END $$


DELIMITER ;




-- 0.1 Fixes/Changes

DELIMITER $$


-- Fix for: Soft-deleted news articles still appear in the news list
DROP PROCEDURE IF EXISTS `media_getNewsList` $$
CREATE PROCEDURE `media_getNewsList` (
	IN `in_cat`			TINYINT(2),
	IN `in_page`		SMALLINT(5),
	IN `in_limit`		TINYINT(3),
	OUT `out_pageCount`	SMALLINT(5),
	OUT `out_realPage`	SMALLINT(5)
) 
BEGIN 
	DECLARE `newsCount`	SMALLINT(5);
	DECLARE `start`		SMALLINT(5);
	
	SELECT COUNT(`id`) INTO `newsCount` 
	FROM `media_news` 
	WHERE ((`in_cat` = 0) OR (`category` = `in_cat`)) 
		AND `deleted` = 0;
	
	SET `out_pageCount` = CEIL(`newsCount` / `in_limit`);
	
	IF (`in_page` > `out_pageCount`) THEN 
		SET `out_realPage` = `out_pageCount`;
	ELSE 
		SET `out_realPage` = `in_page`;
	END IF;
	
	SET `start` = (`out_realPage` * `in_limit`) - `in_limit`;
	
	SELECT `id`, `category`, `title`, `date` 
	FROM `media_news` 
	WHERE ((`in_cat` = 0) OR (`category` = `in_cat`)) 
		AND `deleted` = 0 
	ORDER BY `date` DESC 
	LIMIT `start`,`in_limit`;
END $$


DELIMITER ;
