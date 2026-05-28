#!/usr/bin/env python3
import json, unittest
from unittest.mock import MagicMock
from handler import analyze_sentiment, detect_entities, lambda_handler

class TestSentimentAnalyzer(unittest.TestCase):

    def test_analyze_sentiment_returns_scores(self):
        mock_comprehend = MagicMock()
        mock_comprehend.detect_sentiment.return_value = {
            "Sentiment": "POSITIVE",
            "SentimentScore": {
                "Positive": 0.98,
                "Negative": 0.01,
                "Neutral": 0.01,
                "Mixed": 0.00,
            }
        }
        result = analyze_sentiment("ScoutCloud is amazing!", comprehend=mock_comprehend)
        self.assertEqual(result["sentiment"], "POSITIVE")
        self.assertEqual(result["scores"]["positive"], 0.98)

    def test_detect_entities_extracts_orgs_and_persons(self):
        mock_comprehend = MagicMock()
        mock_comprehend.detect_entities.return_value = {
            "Entities": [
                {"Text": "Knicks", "Type": "ORGANIZATION", "Score": 0.99},
                {"Text": "Jalen Brunson", "Type": "PERSON", "Score": 0.98},
                {"Text": "Madison Square Garden", "Type": "LOCATION", "Score": 0.95},
            ]
        }
        entities = detect_entities("Jalen Brunson led the Knicks at MSG", comprehend=mock_comprehend)
        self.assertEqual(len(entities), 2)
        types = [e["type"] for e in entities]
        self.assertIn("ORGANIZATION", types)
        self.assertIn("PERSON", types)
        texts = [e["text"] for e in entities]
        self.assertIn("Knicks", texts)
        self.assertIn("Jalen Brunson", texts)
        self.assertNotIn("Madison Square Garden", texts)

    def test_full_handler_includes_entities(self):
        mock_comprehend = MagicMock()
        mock_comprehend.detect_sentiment.return_value = {
            "Sentiment": "NEGATIVE",
            "SentimentScore": {
                "Positive": 0.01, "Negative": 0.97,
                "Neutral": 0.01, "Mixed": 0.01
            }
        }
        mock_comprehend.detect_entities.return_value = {
            "Entities": [
                {"Text": "Knicks", "Type": "ORGANIZATION", "Score": 0.99},
            ]
        }
        mock_dynamodb = MagicMock()
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table

        event = {"comments": [{"text": "Knicks lost again!", "user_id": "fan1"}]}
        result = lambda_handler(event, None, comprehend=mock_comprehend, dynamodb=mock_dynamodb)

        self.assertEqual(result["analyzed"], 1)
        self.assertEqual(len(result["results"][0]["entities"]), 1)
        self.assertEqual(result["results"][0]["entities"][0]["text"], "Knicks")
        mock_table.put_item.assert_called_once()
        call_args = mock_table.put_item.call_args[1]["Item"]
        self.assertIn("entities", call_args)

if __name__ == "__main__":
    unittest.main()
