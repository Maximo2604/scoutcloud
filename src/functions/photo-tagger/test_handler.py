#!/usr/bin/env python3
import json, unittest
from unittest.mock import MagicMock, patch
from handler import analyze_photo, store_results, lambda_handler

class TestPhotoTagger(unittest.TestCase):

    def test_analyze_photo_returns_labels(self):
        mock_rekognition = MagicMock()
        mock_rekognition.detect_labels.return_value = {
            "Labels": [
                {"Name": "Basketball", "Confidence": 98.5},
                {"Name": "Person",     "Confidence": 96.2},
                {"Name": "Sports",     "Confidence": 94.1},
            ]
        }
        mock_rekognition.detect_faces.return_value = {
            "FaceDetails": [{"Confidence": 99.9}]
        }
        result = analyze_photo("scoutcloud-assets", "players/photos/jokic.jpg",
                               rekognition=mock_rekognition)
        self.assertEqual(len(result["labels"]), 3)
        self.assertEqual(result["face_count"], 1)
        self.assertTrue(result["is_basketball_photo"])
        mock_rekognition.detect_labels.assert_called_once_with(
            Image={"S3Object": {"Bucket": "scoutcloud-assets", "Name": "players/photos/jokic.jpg"}},
            MaxLabels=10,
            MinConfidence=80.0,
        )

    def test_non_photo_files_are_skipped(self):
        mock_rekognition = MagicMock()
        mock_dynamodb = MagicMock()
        event = {
            "Records": [{
                "s3": {
                    "bucket": {"name": "scoutcloud-assets"},
                    "object": {"key": "static/index.html"},
                }
            }]
        }
        result = lambda_handler(event, None,
                                rekognition=mock_rekognition,
                                dynamodb=mock_dynamodb)
        self.assertEqual(result["processed"], 0)
        mock_rekognition.detect_labels.assert_not_called()

    def test_full_handler_processes_photo(self):
        mock_rekognition = MagicMock()
        mock_rekognition.detect_labels.return_value = {
            "Labels": [{"Name": "Basketball", "Confidence": 99.0}]
        }
        mock_rekognition.detect_faces.return_value = {
            "FaceDetails": [{"Confidence": 99.0}]
        }
        mock_dynamodb = MagicMock()
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        event = {
            "Records": [{
                "s3": {
                    "bucket": {"name": "scoutcloud-assets"},
                    "object": {"key": "players/photos/curry.jpg"},
                }
            }]
        }
        result = lambda_handler(event, None,
                                rekognition=mock_rekognition,
                                dynamodb=mock_dynamodb)
        self.assertEqual(result["processed"], 1)
        mock_table.put_item.assert_called_once()

if __name__ == "__main__":
    unittest.main()
