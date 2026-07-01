import numpy as np
import pandas as pd

def generate_pulse_dataset(num_samples=10000):
    """
    Generates a synthetic biometric dataset mapped to 8 emotional states.
    Strictly aligned to the optimized 13-feature schema (dropped absolute HR & blood O2).
    Simulates HealthKit sparsity for XGBoost/LightGBM training.
    """
    np.random.seed(42)
    
    # 8 Target Classes
    states = ['sleepless', 'anxious', 'depleted', 'struggling', 'recovering', 'restful', 'resilient', 'unknown']
    target_states = np.random.choice(states, size=num_samples)
    
    # Random Hours (0-23) for cyclical encoding
    hours = np.random.randint(0, 24, size=num_samples)
    
    df = pd.DataFrame({
        'State': target_states,
        'time_of_day_sin': np.sin(2 * np.pi * hours / 24),
        'time_of_day_cos': np.cos(2 * np.pi * hours / 24)
    })
    
    # Initialize remaining 11 biometric features (13 total)
    df['hrv_sdnn'] = np.nan
    df['rmssd'] = np.nan 
    df['hrv_7day_slope'] = np.nan
    df['hr_delta_from_resting'] = np.nan
    df['sleep_efficiency'] = np.nan
    df['deep_sleep_pct'] = np.nan
    df['rem_pct'] = np.nan
    df['awakening_count'] = np.nan
    df['late_night_wakefulness'] = 0.0
    df['respiratory_rate'] = np.nan
    df['wrist_temp_delta'] = np.nan

    # Clinical Modifiers based on State
    for idx, row in df.iterrows():
        state = row['State']
        
        if state == 'sleepless':
            df.at[idx, 'late_night_wakefulness'] = 1.0
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(15, 5) # Elevated
            df.at[idx, 'hrv_sdnn'] = np.random.normal(25, 10) # Low
            df.at[idx, 'rmssd'] = np.random.normal(18, 8) # Acute stress
            df.at[idx, 'sleep_efficiency'] = np.random.normal(0.60, 0.1)
            df.at[idx, 'awakening_count'] = np.random.poisson(4)
            df.at[idx, 'respiratory_rate'] = np.random.normal(16, 2)
            
        elif state == 'anxious':
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(20, 8) 
            df.at[idx, 'hrv_sdnn'] = np.random.normal(20, 8) 
            df.at[idx, 'rmssd'] = np.random.normal(15, 6)
            df.at[idx, 'respiratory_rate'] = np.random.normal(19, 2) 
            df.at[idx, 'sleep_efficiency'] = np.random.normal(0.85, 0.05) 
            
        elif state == 'depleted':
            df.at[idx, 'hrv_sdnn'] = np.random.normal(22, 5) 
            df.at[idx, 'rmssd'] = np.random.normal(20, 6)
            df.at[idx, 'hrv_7day_slope'] = np.random.normal(-0.5, 0.2) 
            df.at[idx, 'sleep_efficiency'] = np.random.normal(0.70, 0.1) 
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(2, 3) 
            
        elif state == 'struggling':
            df.at[idx, 'hrv_7day_slope'] = np.random.normal(-0.8, 0.15) 
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(12, 4)
            df.at[idx, 'wrist_temp_delta'] = np.random.normal(0.5, 0.3) 
            df.at[idx, 'rmssd'] = np.random.normal(25, 8)
            
        elif state == 'recovering':
            df.at[idx, 'hrv_7day_slope'] = np.random.normal(0.6, 0.2) 
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(8, 5) 
            df.at[idx, 'sleep_efficiency'] = np.random.normal(0.88, 0.05)
            df.at[idx, 'rmssd'] = np.random.normal(35, 10)
            
        elif state == 'restful':
            df.at[idx, 'hrv_sdnn'] = np.random.normal(60, 15) 
            df.at[idx, 'rmssd'] = np.random.normal(55, 15)
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(-2, 3) 
            df.at[idx, 'sleep_efficiency'] = np.random.normal(0.92, 0.04) 
            df.at[idx, 'respiratory_rate'] = np.random.normal(13, 1.5)
            
        elif state == 'resilient':
            df.at[idx, 'hrv_sdnn'] = np.random.normal(50, 12) 
            df.at[idx, 'rmssd'] = np.random.normal(45, 12)
            df.at[idx, 'hrv_7day_slope'] = np.random.normal(0.3, 0.3)
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(5, 4)
            
        elif state == 'unknown':
            df.at[idx, 'hr_delta_from_resting'] = np.random.normal(5, 10)

    # Fill remaining uninitialized normal distributions wrapped in pd.Series()
    df['deep_sleep_pct'] = df['deep_sleep_pct'].fillna(pd.Series(np.random.normal(0.20, 0.05, num_samples)))
    df['rem_pct'] = df['rem_pct'].fillna(pd.Series(np.random.normal(0.25, 0.05, num_samples)))
    df['wrist_temp_delta'] = df['wrist_temp_delta'].fillna(pd.Series(np.random.normal(0.0, 0.2, num_samples)))
    df['hrv_sdnn'] = df['hrv_sdnn'].fillna(pd.Series(np.random.normal(40, 15, num_samples)))
    df['rmssd'] = df['rmssd'].fillna(pd.Series(np.random.normal(38, 15, num_samples)))
    df['hrv_7day_slope'] = df['hrv_7day_slope'].fillna(pd.Series(np.random.normal(0.0, 0.4, num_samples)))
    df['sleep_efficiency'] = df['sleep_efficiency'].fillna(pd.Series(np.random.normal(0.85, 0.08, num_samples)))
    df['respiratory_rate'] = df['respiratory_rate'].fillna(pd.Series(np.random.normal(15, 2, num_samples)))
    df['awakening_count'] = df['awakening_count'].fillna(pd.Series(np.random.poisson(1, num_samples)))
    df['hr_delta_from_resting'] = df['hr_delta_from_resting'].fillna(pd.Series(np.random.normal(5, 5, num_samples)))

    # Bound percentages to valid constraints (0.0 to 1.0)
    for col in ['sleep_efficiency', 'deep_sleep_pct', 'rem_pct']:
        df[col] = df[col].clip(0.0, 1.0)
    
    # Bound slope (-1.0 to 1.0)
    df['hrv_7day_slope'] = df['hrv_7day_slope'].clip(-1.0, 1.0)

    # Introduce intentional sparsity (HealthKit read delays)
    sparsity_cols = ['hrv_sdnn', 'rmssd', 'sleep_efficiency', 'wrist_temp_delta', 'respiratory_rate']
    for col in sparsity_cols:
        # Randomly mask 15% of the data with NaNs
        mask = np.random.rand(num_samples) < 0.15
        df.loc[mask, col] = np.nan

    return df

if __name__ == "__main__":
    pulse_dataset = generate_pulse_dataset(10000)
    print(pulse_dataset.head())
    print(f"\nMissing Data Breakdown:\n{pulse_dataset.isna().sum()}")
    pulse_dataset.to_csv("synthetic_pulse_dataset.csv", index=False)
    print("\nSynthetic pulse dataset generated and saved to 'synthetic_pulse_dataset.csv'.")