# OvR Image Classifier Trainer

## 概要

OvR Image Classifier Trainerの目的は、事前にトレーニングされた画像分類モデルを行って、APIから画像を取得し、画像の分類を行い、データセットを自動化することです。

## ディレクトリ構成

```
.
├── CatAPIClient/
├── CTFileManager/
├── CTImageLoader/
├── OvRClassification/
├── Dataset/
│   ├── Verified/
│   └── Unverified/
├── OvRImageClassifierTrainerTests/
└── main.swift
```

## 設定オプション

- `fetchImageCount`: 取得する画像の数（デフォルト: 10）
- `classificationThreshold`: 分類の信頼度の閾値（デフォルト: 0.85）

## テスト

`OvRImageClassifierTrainerTests` ディレクトリにユニットテストが含まれており、主に以下の点をテストしています

* 画像データを指定されたラベルのディレクトリに正しく保存できること
* 画像の分類処理がエラーなく完了すること